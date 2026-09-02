# Airflow orchestration

Orchestrates the full pipeline as one DAG, `workday_hr_analytics`
([dags/workday_hr_analytics_dag.py](dags/workday_hr_analytics_dag.py)):

```
dbt_deps -> check_workday_source_freshness -> dbt_seed -> dbt_run_staging
         -> dbt_snapshot -> dbt_run_marts -> dbt_test
```

Same dependency order as [`.github/workflows/dbt_ci.yml`](../.github/workflows/dbt_ci.yml)
and for the same reason: `snap_workers` snapshots a staging view
(`stg_workday__workers`), so staging has to be built first — see the main
[README §8 Data lineage findings](../README.md#8-data-lineage-findings).

This was built against and tested locally on an existing Airflow 3.3.1
docker-compose stack (`~/airflow_home`) — `apache-airflow-providers-snowflake`
was already installed there; `dbt` itself was not, hence the custom image
below. (Originally built on 3.0.0; bumped to 3.3.1 after hitting
[apache/airflow#49689](https://github.com/apache/airflow/issues/49689) — a
3.0.0 dag-processor bug that SIGKILLs every parse after a host sleep/wake
cycle and eventually drops the DAG from the UI. Fixed in 3.0.1+; see the
comment at the top of [`Dockerfile`](Dockerfile).)

## Why a custom image

`dbt-core` pins its own versions of `click`, `jinja2`, `protobuf`, etc. that
can conflict with Airflow's own pins. Installing `dbt-snowflake` straight
into Airflow's environment (e.g. via `_PIP_ADDITIONAL_REQUIREMENTS`, which
the stock `docker-compose.yaml` itself warns is for quick checks only) risks
breaking the scheduler/webserver. [`Dockerfile`](Dockerfile) instead builds
an isolated virtualenv at `/opt/dbt_venv` inside an image extending your
existing `apache/airflow:3.3.1`; the DAG calls `/opt/dbt_venv/bin/dbt`
directly, never Airflow's own Python.

## One-time setup

All commands below assume your existing Airflow lives at `~/airflow_home`
(adjust the paths if yours differs) and this repo is checked out at
`~/claude_code_playground/workday-fivetran-dbt-snowflake` (adjust likewise).

### 1. Build the custom image

```bash
cd ~/claude_code_playground/workday-fivetran-dbt-snowflake/airflow
docker build -t workday-hr-airflow:latest -f Dockerfile ..
```

### 2. Point your docker-compose at it, and mount this repo

Edit `~/airflow_home/docker-compose.yaml`. In the `x-airflow-common` block:

```yaml
x-airflow-common:
  &airflow-common
  image: workday-hr-airflow:latest   # was: apache/airflow:3.3.1
  ...
  volumes:
    - ${AIRFLOW_PROJ_DIR:-.}/dags:/opt/airflow/dags
    - ${AIRFLOW_PROJ_DIR:-.}/logs:/opt/airflow/logs
    - ${AIRFLOW_PROJ_DIR:-.}/config:/opt/airflow/config
    - ${AIRFLOW_PROJ_DIR:-.}/plugins:/opt/airflow/plugins
    # add this line:
    - ~/claude_code_playground/workday-fivetran-dbt-snowflake:/opt/airflow/workday-fivetran-dbt-snowflake
```

I haven't made this edit for you — it's a change to a different project
(`~/airflow_home`), outside this repo, and outside what you asked me to do
directly. Say the word if you'd like me to make it for you instead of just
documenting it.

### 3. Get the DAG into Airflow's dags folder

A symlink keeps it in sync with anything you change in this repo, without
duplicating the file:

```bash
ln -s ~/claude_code_playground/workday-fivetran-dbt-snowflake/airflow/dags/workday_hr_analytics_dag.py \
      ~/airflow_home/dags/workday_hr_analytics_dag.py
```

### 4. Create the `snowflake_default` Airflow Connection

Via the CLI (or Admin → Connections in the UI) — this is the *only* place
credentials live; the DAG reads them at task-execution time and never
hardcodes anything:

```bash
docker exec -it airflow_home-airflow-apiserver-1 airflow connections add snowflake_default \
  --conn-type snowflake \
  --conn-login "<your Snowflake username>" \
  --conn-password "<your Snowflake password>" \
  --conn-extra '{
      "account": "VHWFFGT-SZ96994",
      "warehouse": "WH_DBT_TRANSFORM",
      "database": "HR_ANALYTICS",
      "role": "DBT_TRANSFORMER",
      "schema": "orchestrated"
    }'
```

(Run this yourself — I won't type your password for you.)

### 5. (Optional) Override the dbt project path

The DAG defaults to `/opt/airflow/workday-fivetran-dbt-snowflake/dbt_project`,
matching the mount in step 2. If you mount it somewhere else, set the
Airflow Variable instead of editing the DAG:

```bash
docker exec -it airflow_home-airflow-apiserver-1 airflow variables set dbt_project_dir \
  "/opt/airflow/workday-fivetran-dbt-snowflake/dbt_project"
```

### 6. Rebuild and restart

```bash
cd ~/airflow_home
docker compose up -d --build
```

### 7. Unpause and trigger

```bash
docker exec -it airflow_home-airflow-apiserver-1 airflow dags unpause workday_hr_analytics
docker exec -it airflow_home-airflow-apiserver-1 airflow dags trigger workday_hr_analytics
```

Or from the UI at `http://localhost:8080`.

## About the `check_workday_source_freshness` task

It runs `dbt source freshness --select source:workday`, reusing the
freshness blocks already declared in
[`_workday__sources.yml`](../dbt_project/models/staging/workday/_workday__sources.yml)
— this is dbt's own recommended way to gate on Fivetran having actually
synced (see `docs/architecture.md` §7), rather than adding a Fivetran
provider dependency this demo doesn't otherwise need.

**Demo caveat:** this repo's sample data was loaded once via
`snowflake/02_load_sample_data.sql`, not by a continuously-syncing Fivetran
connector. `_fivetran_synced` will go stale and this check will start
failing once it's older than the `error_after` threshold (24h for most
sources, 2h for `workday_time_entries`) in `_workday__sources.yml`. The task
catches that and turns it into an Airflow **skip** (visible, not silently
swallowed) so the rest of the DAG still runs for demo purposes — remove that
`try`/`except` in the DAG once this is pointed at a real, continuously
syncing Fivetran connector, so a genuinely stale source blocks the pipeline
like it should in production.

## What's not wired in here

- **Triggering the actual Fivetran sync.** This DAG starts from RAW already
  being fresh (checked, not caused). A real deployment would add a
  `FivetranOperator` + `FivetranSensor` (from the separate
  `airflow-provider-fivetran` package) as the first task, using Fivetran's
  API to kick off and wait for the sync before `dbt_deps` runs — omitted
  here since this repo has no live Fivetran connector to trigger (see the
  main README §3 Quickstart).
- **Per-domain scheduling.** `docs/architecture.md` §2 recommends different
  sync cadences per domain (6h HCM, 1h Time Entry, 24h Benefits) — this DAG
  runs everything on one daily schedule for simplicity. Splitting into
  per-domain DAGs is the natural next step if you need that.
