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
| **Student (Enrollment)** | Student, Academic Period, Program of Study, Course Registration | 1 row per student / term / course registration | P1 |
| **Finance (Financials)** | Ledger Account, Cost Center, Journal Entry / GL Transaction | 1 row per GL journal line | P1 |

This repo implements **HCM + Time Tracking + Payroll + Benefits + Student + Finance (P0/P1)** end-to-end; Recruiting/Comp/Talent follow the identical staging→mart pattern and are called out as extension points. Student and Finance are separate Workday modules from HCM (Workday Student and Workday Financials, respectively) — each ships as its own Fivetran connector, but conforms into the same Snowflake database and shares dimensions with HCM where the business object is genuinely the same (Cost Center ↔ Supervisory Organization; see §3's bus matrix).

## 2. Source system considerations & Fivetran connector

- **Connector**: Fivetran's Workday connector uses Workday's **RaaS (Report-as-a-Service)** / Custom Report + Workday REST/SOAP API under a dedicated **Integration System User (ISU)** with a security group scoped to read-only access on the domains above. Never reuse a human's credentials.
- **Sync frequency**: 6h for HCM/Org/Position (slow-changing, high blast-radius if stale), 1h for Time Entry during open pay periods, 24h for Benefits/Recruiting (low urgency), 24h for Student/Enrollment (registration windows are read-heavy but not minute-fresh), 12h for Finance/GL (month-end close wants same-day visibility, not real-time). Configure per-connector schedules in Fivetran, not a single global cadence.
- **Delta handling**: Fivetran uses cursor-based incremental sync keyed on Workday's `Last_Modified` / effective-dated `Transaction_Log` where the report supports it; objects without a native cursor fall back to full-table re-sync + Fivetran's own row hashing to emit only changed rows downstream. Effective-dated Workday objects (Worker, Position, Comp) surface **all historical effective-dated rows**, not just current — this is what powers SCD2 in the dbt layer (§3).
- **Schema evolution**: set the connector to `ALLOW COLUMN ADDITIONS` (never `ALLOW ALL`, which can silently widen/retype columns and break downstream models). New Workday custom fields land as new nullable columns in `RAW`; dbt sources are declared explicitly in `sources.yml` so a new raw column is a no-op until intentionally added to a staging model. Set Fivetran alerting on schema-change events.
- **Recommended Workday reports/tables to expose to Fivetran**: `Worker`, `Worker_Position`, `Job_Profile`, `Supervisory_Organization`, `Location`, `Pay_Result`, `Pay_Result_Earning`, `Pay_Result_Deduction`, `Pay_Group`, `Time_Entry`, `Time_Off_Entry`, `Benefit_Election`, `Benefit_Plan`, `Job_Requisition`, `Application`, `Academic_Period`, `Program_Of_Study`, `Student`, `Student_Registration`, `Ledger_Account`, `Cost_Center`, `Journal_Entry`. Each becomes one Fivetran destination table in `RAW.WORKDAY_*`, one dbt source table, and (mostly) one staging model — see [`data_dictionary.md`](data_dictionary.md).
- **Separate connectors, one warehouse**: Workday Student and Workday Financials are provisioned as **separate Fivetran connectors** from HCM/Payroll (Workday licenses/exposes them as distinct modules with their own RaaS endpoints and ISU security groups) — each with its own sync schedule below — but all land in the same `RAW` schema of the same `HR_ANALYTICS` database, so dbt can join across them without cross-database queries.
- **Fivetran metadata columns** (`_fivetran_synced`, `_fivetran_deleted`, `_fivetran_id`) are preserved through `RAW` and consumed in staging for freshness tests and soft-delete handling (`where not _fivetran_deleted` in `stg_*` models).

## 3. Dimensional modeling approach

- **Staging (`stg_`)**: 1:1 with source table, views, renaming to `snake_case` business names, casting types, trimming strings, no joins, no aggregation. Deleted-row filtering happens here.
- **Intermediate (`int_`)**: multi-source joins/business logic not yet at BI grain (e.g. `int_workers_joined_positions`). Ephemeral or view materialization; not exposed to BI tools directly.
- **Marts — conformed dimensions**:
  - `dim_employee` — **SCD Type 2** (via dbt snapshot on `stg_workday__workers` + position/comp attributes), because job title, manager, department, and compensation band changing must be attributable to the pay period/fact rows active *at that time*. Surrogate key = `dbt_utils.generate_surrogate_key(['employee_id','dbt_valid_from'])`; `is_current` flag for easy "as-of-today" filtering.
  - `dim_department`, `dim_location`, `dim_position`, `dim_pay_group` — **SCD Type 1** (overwrite), low cardinality reference-ish data where history isn't analytically interesting for this use case; upgrade to SCD2 if org-restructure history matters.
  - `dim_date` — generated calendar spine (fiscal + calendar), no source dependency.
  - `dim_student` — **SCD Type 2** (via dbt snapshot on `stg_workday__students`), same reasoning as `dim_employee`: enrollment status and program changes must be attributable to the registration/course rows active *at that time*.
  - `dim_program`, `dim_academic_period` — **SCD Type 1**, low cardinality (programs and terms rarely change once defined).
  - `dim_cost_center` — **SCD Type 1**, denormalizes `department_name`/`division` from `dim_department` so Finance reports don't need a second join into `MARTS_CORE` — see the bus-matrix note below.
  - `dim_gl_account` — **SCD Type 1**, the Chart of Accounts.
- **Marts — atomic facts** (grain stated explicitly, additive measures only, all FKs to conformed dims):
  - `fact_hours_worked` — grain: 1 row per worker per time-entry per day. Measures: `hours_worked`, `overtime_hours`.
  - `fact_pay` — grain: 1 row per worker per pay-period per earning/deduction code. Measures: `amount`.
  - `fact_benefits_enrollment` — grain: 1 row per worker per plan per enrollment effective date. Semi-additive (`coverage_amount`) — use period-end snapshot semantics, not SUM across time.
  - `fact_enrollment` — grain: 1 row per student per course registration per academic period. Measures: `credit_hours` (additive within a period; use a cumulative-snapshot pattern, not SUM, for "total credits earned").
  - `fact_gl_transactions` — grain: 1 row per GL journal line. Measures: `amount` (signed — debit positive, credit negative; every `journal_entry_id`'s lines sum to zero, tested by `tests/assert_gl_journal_entries_balance.sql`).
- **Conformed bus matrix**: `dim_employee`, `dim_department`, `dim_location`, `dim_date` are shared across the HR facts so cross-domain queries (e.g. "overtime hours by department by month") don't require fact-to-fact joins. **Finance conforms to HCM**: `dim_cost_center.department_id` is a genuine, tested foreign key into `dim_department` — in this tenant, Workday Cost Center and Supervisory Organization are the same underlying org hierarchy, so `fact_gl_transactions` can be sliced by the identical department dimension `fact_pay` uses, which is what makes payroll→GL reconciliation (`tests/assert_payroll_reconciles_to_gl.sql`) a same-grain join instead of a fuzzy match. **Student does not force a fake conformance to HCM**: `dim_program.academic_unit` is deliberately a free-text attribute, not an FK to `dim_department` — in most Workday tenants, Academic Unit (School of Engineering, College of Business) and Supervisory Organization (an employee's reporting org) are configured as related but distinct hierarchies; asserting a hard FK here would pass on this repo's synthetic data and silently break in any real tenant where that assumption doesn't hold.

## 4. Snowflake schema design

```
DATABASE: HR_ANALYTICS
 ├── SCHEMA RAW              -- Fivetran-owned, append-only, 1:1 Workday replica
 ├── SCHEMA STAGING           -- dbt stg_ views
 ├── SCHEMA INTERMEDIATE      -- dbt int_ views/ephemeral
 ├── SCHEMA MARTS_CORE        -- dim_employee, dim_department, dim_position, dim_location, dim_date
 ├── SCHEMA MARTS_HR          -- fact_hours_worked, fact_pay, fact_benefits_enrollment
 ├── SCHEMA MARTS_STUDENT     -- dim_student, dim_program, dim_academic_period, fact_enrollment
 ├── SCHEMA MARTS_FINANCE     -- dim_gl_account, dim_cost_center, fact_gl_transactions
 └── SCHEMA SNAPSHOTS         -- dbt snapshot tables (SCD2 raw history: snap_workers, snap_students)
```

- **Warehouses**: `WH_FIVETRAN_LOAD` (X-Small, auto-suspend 60s) for RAW ingestion; `WH_DBT_TRANSFORM` (Small/Medium, auto-suspend 60s, auto-scale 1–3 clusters) for scheduled dbt runs; `WH_BI_QUERY` (Medium, auto-suspend 300s) for BI tool queries — isolating workloads prevents a heavy BI dashboard from queuing behind a transform job (or vice versa) and gives clean cost attribution per workload via `QUERY_HISTORY.WAREHOUSE_NAME`.
- **Clustering**: Snowflake micro-partitions are automatic; add explicit `CLUSTER BY` only on large, filter-heavy facts. `fact_hours_worked` and `fact_pay` cluster on `(pay_period_end_date)` (or `date_key`) since almost every downstream query filters by date range — keeps pruning effective as tables grow past tens of millions of rows. `fact_enrollment` clusters on `(academic_period_id)` — Student queries are almost always scoped to a single term. `fact_gl_transactions` clusters on `(transaction_date)`, matching the HR facts' pattern, since Finance queries are period-driven the same way (month-end close, quarter close). Don't cluster small dims.
- **Data catalog**: Snowflake **tags** (`PII`, `data_domain`) on sensitive columns (SSN-like IDs, comp amounts, DOB) + **row access policies**/**dynamic data masking** on `dim_employee.compensation_band` for non-HR roles; dbt-generated docs (`dbt docs generate`) published as the transformation-layer catalog; optionally register in a data catalog tool (Atlan, Select Star) reading Snowflake's `ACCOUNT_USAGE` views.

## 5. dbt project structure

See `dbt_project/` in this repo. Key conventions: one model = one file = one `ref()`-able unit; `sources.yml` declares the Fivetran-owned RAW tables with `freshness` blocks; `schema.yml` per folder documents + tests every mart column; `macros/generate_schema_name.sql` overrides dbt's default so `target.name == 'prod'` writes to the exact schema names above instead of `<target_schema>_marts_core`; deployment via a scheduled `dbt Cloud` job or `dbt build` step in CI/CD (Airflow, GitHub Actions, or Fivetran's own dbt-in-Fivetran feature) triggered after the Fivetran sync completes (webhook or polling `_fivetran_synced` freshness).

## 6. Data quality & governance

- **Source reconciliation**: `dbt source freshness` on every RAW table (alert if `Worker` hasn't synced in >12h); row-count reconciliation macro comparing `RAW` vs Workday report export counts during UAT.
- **Lineage**: dbt's built-in DAG (`dbt docs generate` → `graph.gpickle`/`manifest.json`) gives column-level lineage from RAW to marts automatically; exposed via `dbt docs serve` or ingested into a catalog tool.
- **Anomaly detection**: dbt tests (`not_null`, `unique`, `relationships`, `accepted_values`) on every mart PK/FK; singular tests for business rules (`tests/assert_positive_hours.sql` — no negative worked hours; `tests/assert_gl_journal_entries_balance.sql` — every journal entry's lines sum to zero; `tests/assert_payroll_reconciles_to_gl.sql` — payroll's Earnings total ties to the GL's Salaries Expense posting per cost center per pay period); optionally `dbt-elementary` or `dbt-expectations` package for volume/freshness/schema-drift anomaly detection in production.
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
- `fact_pay` reconciles to `fact_gl_transactions`' payroll-sourced Salaries Expense postings, by cost center and pay period, within the same ±$0.01 tolerance — `tests/assert_payroll_reconciles_to_gl.sql` is this acceptance test, not just a spot check.
- `dim_employee` SCD2 correctly reconstructs "who was an employee's manager on date X" for a spot-checked historical sample; `dim_student` SCD2 does the same for "what was a student's enrollment status on date X."
- Every GL journal entry balances (`tests/assert_gl_journal_entries_balance.sql`, zero-row pass) — a non-negotiable Finance acceptance gate, not a warning-level check.
- End-to-end latency (Workday transaction → available in `MARTS`) meets the domain SLA (Time Entry within 4h during pay-period close, HCM within 24h, Finance/GL within 24h for month-end close).

## 9. Assumptions & trade-offs

- Assumes Workday tenant exposes the standard RaaS/API surface Fivetran's connector expects; heavily customized Workday tenants may need custom Workday Studio reports before Fivetran can extract some fields.
- SCD2 only on `dim_employee` and `dim_student`; other dims use SCD1 to control storage/complexity — revisit if org-history or curriculum-history analytics becomes a requirement.
- Sample data in this repo is small (dozens of rows) to keep the repo lightweight; clustering/incremental strategies are described for production scale (millions of rows) even though the demo dataset doesn't need them.
- Payroll amounts are modeled as a single `fact_pay` at earning/deduction grain rather than separate gross/net facts — simpler star, slightly more work for "net pay" queries (sum with sign convention on deduction rows).
- `fact_gl_transactions` models a simplified two-line-minimum journal entry (expense/liability + cash), not a full sub-ledger with AR/AP aging, accruals, or multi-currency — sufficient to demonstrate reconciliation, not a Finance system of record.
- `dim_cost_center.department_id` assumes this tenant's Cost Center hierarchy is 1:1 with Supervisory Organization. Real Workday Financials+HCM deployments vary here — some tenants run genuinely independent hierarchies, in which case this FK (and the payroll→GL reconciliation join) would need a proper cross-reference/mapping table instead of a direct join.
- `dim_program.academic_unit` is intentionally *not* FK'd to `dim_department`, for the reason given in §3 — Academic Unit and Supervisory Org are related-but-distinct in most tenants, unlike Cost Center/Department.
