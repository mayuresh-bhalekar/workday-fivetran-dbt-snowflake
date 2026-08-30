# Architecture & Design Brief: Workday → Fivetran → dbt → Snowflake

## 1. Data sources and core Workday domains

| Domain | Key Workday objects/reports | Grain captured | Priority |
|---|---|---|---|
| **HCM (Core)** | Worker, Position, Job Profile, Organization/Supervisory Org, Location | 1 row per worker / position / org | P0 |
| **Payroll** | Pay Result, Earning, Deduction, Pay Group, Payslip | 1 row per worker per pay period per earning/deduction code | P0 |
| **Time Tracking** | Time Entry, Time Off/Absence, Time Block | 1 row per time entry (clock-in/out or daily total) | P0 |
| **Benefits** | Benefit Election, Enrollment Event, Dependent, Plan/Coverage | 1 row per worker per plan per effective-dated event | P1 |
| **Recruiting** | Job Requisition, Candidate, Application, Offer | 1 row per requisition / application | P1 |
| **Compensation** | Comp Plan, Comp Package, Merit/Bonus Event | 1 row per worker per comp event | P2 |
| **Talent/Performance** | Review, Goal, Talent Assessment | 1 row per review cycle per worker | P2 |

This repo implements **HCM + Time Tracking + Payroll + Benefits (P0/P1)** end-to-end; Recruiting/Comp/Talent follow the identical staging→mart pattern and are called out as extension points.

## 2. Source system considerations & Fivetran connector

- **Connector**: Fivetran's Workday connector uses Workday's **RaaS (Report-as-a-Service)** / Custom Report + Workday REST/SOAP API under a dedicated **Integration System User (ISU)** with a security group scoped to read-only access on the domains above. Never reuse a human's credentials.
- **Sync frequency**: 6h for HCM/Org/Position (slow-changing, high blast-radius if stale), 1h for Time Entry during open pay periods, 24h for Benefits/Recruiting (low urgency). Configure per-connector schedules in Fivetran, not a single global cadence.
- **Delta handling**: Fivetran uses cursor-based incremental sync keyed on Workday's `Last_Modified` / effective-dated `Transaction_Log` where the report supports it; objects without a native cursor fall back to full-table re-sync + Fivetran's own row hashing to emit only changed rows downstream. Effective-dated Workday objects (Worker, Position, Comp) surface **all historical effective-dated rows**, not just current — this is what powers SCD2 in the dbt layer (§3).
- **Schema evolution**: set the connector to `ALLOW COLUMN ADDITIONS` (never `ALLOW ALL`, which can silently widen/retype columns and break downstream models). New Workday custom fields land as new nullable columns in `RAW`; dbt sources are declared explicitly in `sources.yml` so a new raw column is a no-op until intentionally added to a staging model. Set Fivetran alerting on schema-change events.
- **Recommended Workday reports/tables to expose to Fivetran**: `Worker`, `Worker_Position`, `Job_Profile`, `Supervisory_Organization`, `Location`, `Pay_Result`, `Pay_Result_Earning`, `Pay_Result_Deduction`, `Pay_Group`, `Time_Entry`, `Time_Off_Entry`, `Benefit_Election`, `Benefit_Plan`, `Job_Requisition`, `Application`. Each becomes one Fivetran destination table in `RAW.WORKDAY_*`, one dbt source table, and (mostly) one staging model — see [`data_dictionary.md`](data_dictionary.md).
- **Fivetran metadata columns** (`_fivetran_synced`, `_fivetran_deleted`, `_fivetran_id`) are preserved through `RAW` and consumed in staging for freshness tests and soft-delete handling (`where not _fivetran_deleted` in `stg_*` models).

## 3. Dimensional modeling approach

- **Staging (`stg_`)**: 1:1 with source table, views, renaming to `snake_case` business names, casting types, trimming strings, no joins, no aggregation. Deleted-row filtering happens here.
- **Intermediate (`int_`)**: multi-source joins/business logic not yet at BI grain (e.g. `int_workers_joined_positions`). Ephemeral or view materialization; not exposed to BI tools directly.
- **Marts — conformed dimensions**:
  - `dim_employee` — **SCD Type 2** (via dbt snapshot on `stg_workday__workers` + position/comp attributes), because job title, manager, department, and compensation band changing must be attributable to the pay period/fact rows active *at that time*. Surrogate key = `dbt_utils.generate_surrogate_key(['employee_id','dbt_valid_from'])`; `is_current` flag for easy "as-of-today" filtering.
  - `dim_department`, `dim_location`, `dim_position`, `dim_pay_group` — **SCD Type 1** (overwrite), low cardinality reference-ish data where history isn't analytically interesting for this use case; upgrade to SCD2 if org-restructure history matters.
  - `dim_date` — generated calendar spine (fiscal + calendar), no source dependency.
- **Marts — atomic facts** (grain stated explicitly, additive measures only, all FKs to conformed dims):
  - `fact_hours_worked` — grain: 1 row per worker per time-entry per day. Measures: `hours_worked`, `overtime_hours`.
  - `fact_pay` — grain: 1 row per worker per pay-period per earning/deduction code. Measures: `amount`.
  - `fact_benefits_enrollment` — grain: 1 row per worker per plan per enrollment effective date. Semi-additive (`coverage_amount`) — use period-end snapshot semantics, not SUM across time.
- **Conformed bus matrix**: `dim_employee`, `dim_department`, `dim_location`, `dim_date` are shared across all three facts so cross-domain queries (e.g. "overtime hours by department by month") don't require fact-to-fact joins.

## 4. Snowflake schema design

```
DATABASE: HR_ANALYTICS
 ├── SCHEMA RAW           -- Fivetran-owned, append-only, 1:1 Workday replica
 ├── SCHEMA STAGING        -- dbt stg_ views
 ├── SCHEMA INTERMEDIATE   -- dbt int_ views/ephemeral
 ├── SCHEMA MARTS_CORE     -- dim_employee, dim_department, dim_position, dim_location, dim_date
 ├── SCHEMA MARTS_HR       -- fact_hours_worked, fact_pay, fact_benefits_enrollment
 └── SCHEMA SNAPSHOTS      -- dbt snapshot tables (SCD2 raw history)
```

- **Warehouses**: `WH_FIVETRAN_LOAD` (X-Small, auto-suspend 60s) for RAW ingestion; `WH_DBT_TRANSFORM` (Small/Medium, auto-suspend 60s, auto-scale 1–3 clusters) for scheduled dbt runs; `WH_BI_QUERY` (Medium, auto-suspend 300s) for BI tool queries — isolating workloads prevents a heavy BI dashboard from queuing behind a transform job (or vice versa) and gives clean cost attribution per workload via `QUERY_HISTORY.WAREHOUSE_NAME`.
- **Clustering**: Snowflake micro-partitions are automatic; add explicit `CLUSTER BY` only on large, filter-heavy facts. `fact_hours_worked` and `fact_pay` cluster on `(pay_period_end_date)` (or `date_key`) since almost every downstream query filters by date range — keeps pruning effective as tables grow past tens of millions of rows. Don't cluster small dims.
- **Data catalog**: Snowflake **tags** (`PII`, `data_domain`) on sensitive columns (SSN-like IDs, comp amounts, DOB) + **row access policies**/**dynamic data masking** on `dim_employee.compensation_band` for non-HR roles; dbt-generated docs (`dbt docs generate`) published as the transformation-layer catalog; optionally register in a data catalog tool (Atlan, Select Star) reading Snowflake's `ACCOUNT_USAGE` views.

## 5. dbt project structure

See `dbt_project/` in this repo. Key conventions: one model = one file = one `ref()`-able unit; `sources.yml` declares the Fivetran-owned RAW tables with `freshness` blocks; `schema.yml` per folder documents + tests every mart column; `macros/generate_schema_name.sql` overrides dbt's default so `target.name == 'prod'` writes to the exact schema names above instead of `<target_schema>_marts_core`; deployment via a scheduled `dbt Cloud` job or `dbt build` step in CI/CD (Airflow, GitHub Actions, or Fivetran's own dbt-in-Fivetran feature) triggered after the Fivetran sync completes (webhook or polling `_fivetran_synced` freshness).

## 6. Data quality & governance

- **Source reconciliation**: `dbt source freshness` on every RAW table (alert if `Worker` hasn't synced in >12h); row-count reconciliation macro comparing `RAW` vs Workday report export counts during UAT.
- **Lineage**: dbt's built-in DAG (`dbt docs generate` → `graph.gpickle`/`manifest.json`) gives column-level lineage from RAW to marts automatically; exposed via `dbt docs serve` or ingested into a catalog tool.
- **Anomaly detection**: dbt tests (`not_null`, `unique`, `relationships`, `accepted_values`) on every mart PK/FK; singular tests for business rules (`tests/assert_positive_hours.sql` — no negative worked hours); optionally `dbt-elementary` or `dbt-expectations` package for volume/freshness/schema-drift anomaly detection in production.
- **Auditing**: every mart carries `_loaded_at`, `dbt_updated_at`, and (for SCD2) `dbt_valid_from`/`dbt_valid_to`; `RAW` retains Fivetran's `_fivetran_synced` timestamp so any row can be traced back to its exact sync batch.

## 7. Performance & cost optimization

- Materialize staging as **views** (cheap, always fresh, no storage cost) and marts as **tables** or **incremental** models (facts use `incremental` with `unique_key` + `is_incremental()` filtering on `_fivetran_synced > (select max(_loaded_at) from {{ this }})` to avoid full-table rebuilds).
- Use Snowflake's **result cache** and **warehouse cache** — keep the BI warehouse warm during business hours (`auto_suspend` tuned to usage pattern, not always 60s) so repeated dashboard queries hit cache instead of re-scanning.
- Right-size warehouses per workload (§4) and enable **multi-cluster auto-scale** only on the BI warehouse where concurrency (not single-query size) is the bottleneck.
- Schedule dbt runs to start only after Fivetran sync completion (avoid transforming half-synced data and re-running for nothing) — use Fivetran's webhook or `dbt source freshness` as the gate.
- Prune facts with clustering keys (§4) and avoid `SELECT *` from RAW in staging models — select only needed columns to reduce scan bytes even though Snowflake is columnar, this still helps join performance downstream.

## 8. Success metrics & acceptance criteria

- 100% of P0 domain source tables have a corresponding tested `stg_` model with `not_null`/`unique` on natural keys.
- `dbt build` runs green (0 test failures) in CI on every PR; `dbt source freshness` passes within SLA (Worker ≤12h, Time Entry ≤2h stale-tolerance).
- `fact_hours_worked` and `fact_pay` reconcile to Workday's own payroll register total within a defined tolerance (e.g. ±$0.01 aggregate) for a sample pay period — the acceptance test before go-live.
- `dim_employee` SCD2 correctly reconstructs "who was an employee's manager on date X" for a spot-checked historical sample.
- End-to-end latency (Workday transaction → available in `MARTS`) meets the domain SLA (Time Entry within 4h during pay-period close, HCM within 24h).

## 9. Assumptions & trade-offs

- Assumes Workday tenant exposes the standard RaaS/API surface Fivetran's connector expects; heavily customized Workday tenants may need custom Workday Studio reports before Fivetran can extract some fields.
- SCD2 only on `dim_employee`; other dims use SCD1 to control storage/complexity — revisit if org-history analytics becomes a requirement.
- Sample data in this repo is small (dozens of rows) to keep the repo lightweight; clustering/incremental strategies are described for production scale (millions of rows) even though the demo dataset doesn't need them.
- Payroll amounts are modeled as a single `fact_pay` at earning/deduction grain rather than separate gross/net facts — simpler star, slightly more work for "net pay" queries (sum with sign convention on deduction rows).
