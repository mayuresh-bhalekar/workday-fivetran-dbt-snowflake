# Testing & Monitoring Plan

## 1. Test layers

| Layer | Test type | Tooling | Example in this repo |
|---|---|---|---|
| Source (RAW) | Freshness | `dbt source freshness` | `sources.yml` → `freshness:` blocks per Workday table |
| Staging | Schema tests | dbt generic tests | `not_null`/`unique` on natural keys in `_workday__models.yml` |
| Marts | Schema tests | dbt generic tests | `unique`+`not_null` on surrogate keys, `relationships` on all FKs |
| Marts | Business-rule tests | dbt singular tests | `tests/assert_positive_hours.sql`, `tests/assert_terminated_employees_have_termination_date.sql` |
| Marts | Accepted values | dbt generic tests | `accepted_values` on `worker_status`, `plan_type`, `code_type`, `enrollment_status`, `registration_status`, `account_type` |
| Marts (Finance) | Double-entry integrity | dbt singular test | `tests/assert_gl_journal_entries_balance.sql` — every `journal_entry_id`'s lines sum to zero |
| Cross-system | Reconciliation | manual/CI query + dbt singular test | row counts + sum(`amount`) in `fact_pay` vs. Workday payroll register export each pay period during UAT; `tests/assert_payroll_reconciles_to_gl.sql` automates the `fact_pay` ↔ `fact_gl_transactions` half of that in CI |

## 2. CI (on every pull request)

1. `sqlfluff lint` — SQL style/syntax gate (`.sqlfluff` config, dbt templater).
2. `dbt deps`
3. `dbt seed --target ci`
4. `dbt snapshot --target ci`
5. `dbt build --target ci` — runs models + all tests against an isolated CI schema (see `dbt_project/profiles_example.yml`, `ci` target); fails the PR on any test failure.
6. (Optional) `dbt docs generate` artifact upload for reviewers.

See `.github/workflows/dbt_ci.yml`.

## 3. Production monitoring

- **Freshness alerting**: scheduled `dbt source freshness` job every hour; Slack/email alert via CI step or dbt Cloud notification if any source exceeds its `error_after` threshold (Worker: 12h, Time Entry: 2h).
- **Job success/failure**: orchestrator (Airflow/dbt Cloud/GitHub Actions cron) alerts on non-zero exit from `dbt build`.
- **Test-failure trend**: track `dbt build` test pass/fail counts over time (dbt Cloud's built-in run history, or parse `run_results.json` in CI and push to a metrics table) to catch slow-creeping data-quality regressions, not just hard failures.
- **Volume anomaly detection**: (extension) `dbt-expectations` or `dbt-elementary` package for row-count/volume anomaly detection on `fact_hours_worked` and `fact_pay` — a sudden 50% drop in daily time entries during a pay period is a strong signal of an upstream Workday/Fivetran sync issue, not a real business event. Apply the same pattern to `fact_enrollment` around registration windows (a term's add/drop deadline) and `fact_gl_transactions` around month-end close.
- **PII access monitoring**: Snowflake `ACCESS_HISTORY` / `QUERY_HISTORY` review on tagged PII columns (`dim_employee.compensation_band`, DOB-like fields) for unusual access patterns.

## 4. Acceptance checklist before promoting to production

- [ ] All P0 source tables have `stg_` models with `not_null`+`unique` on natural key
- [ ] `dbt build` green in CI on the release branch
- [ ] Reconciliation: `fact_pay` aggregate matches Workday payroll register for at least one full pay period within tolerance
- [ ] Reconciliation: `tests/assert_payroll_reconciles_to_gl.sql` and `tests/assert_gl_journal_entries_balance.sql` both pass (zero rows)
- [ ] `dim_employee` SCD2 spot-checked: manager/department as-of a historical date matches Workday's own effective-dated report
- [ ] `dim_student` SCD2 spot-checked: enrollment status as-of a historical date matches Workday Student's own effective-dated report
- [ ] `dim_cost_center.department_id` confirmed 1:1 against this tenant's actual Cost Center ↔ Supervisory Org configuration (see architecture.md §9 assumption) before trusting the payroll→GL reconciliation join
- [ ] Freshness SLAs configured and alerting verified (trigger a deliberate stale-source test)
- [ ] `dbt docs` published and lineage reviewed by a second engineer
