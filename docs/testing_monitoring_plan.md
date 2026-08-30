# Testing & Monitoring Plan

## 1. Test layers

| Layer | Test type | Tooling | Example in this repo |
|---|---|---|---|
| Source (RAW) | Freshness | `dbt source freshness` | `sources.yml` → `freshness:` blocks per Workday table |
| Staging | Schema tests | dbt generic tests | `not_null`/`unique` on natural keys in `_workday__models.yml` |
| Marts | Schema tests | dbt generic tests | `unique`+`not_null` on surrogate keys, `relationships` on all FKs |
| Marts | Business-rule tests | dbt singular tests | `tests/assert_positive_hours.sql`, `tests/assert_pay_amount_not_null.sql` |
| Marts | Accepted values | dbt generic tests | `accepted_values` on `worker_status`, `plan_type`, `code_type` |
| Cross-system | Reconciliation | manual/CI query | row counts + sum(`amount`) in `fact_pay` vs. Workday payroll register export, run each pay period during UAT |

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
- **Volume anomaly detection**: (extension) `dbt-expectations` or `dbt-elementary` package for row-count/volume anomaly detection on `fact_hours_worked` and `fact_pay` — a sudden 50% drop in daily time entries during a pay period is a strong signal of an upstream Workday/Fivetran sync issue, not a real business event.
- **PII access monitoring**: Snowflake `ACCESS_HISTORY` / `QUERY_HISTORY` review on tagged PII columns (`dim_employee.compensation_band`, DOB-like fields) for unusual access patterns.

## 4. Acceptance checklist before promoting to production

- [ ] All P0 source tables have `stg_` models with `not_null`+`unique` on natural key
- [ ] `dbt build` green in CI on the release branch
- [ ] Reconciliation: `fact_pay` aggregate matches Workday payroll register for at least one full pay period within tolerance
- [ ] `dim_employee` SCD2 spot-checked: manager/department as-of a historical date matches Workday's own effective-dated report
- [ ] Freshness SLAs configured and alerting verified (trigger a deliberate stale-source test)
- [ ] `dbt docs` published and lineage reviewed by a second engineer
