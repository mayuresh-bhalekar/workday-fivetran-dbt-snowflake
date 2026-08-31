"""Orchestrates the Workday -> Fivetran -> Snowflake -> dbt pipeline end to end.

    Workday --(Fivetran sync)--> RAW --dbt--> STAGING --dbt snapshot--> SNAPSHOTS
                                                    |
                                                    v
                                         INTERMEDIATE + MARTS (dims, facts) --dbt test--> done
"""

from __future__ import annotations

import os
import subprocess
from datetime import datetime

from airflow.exceptions import AirflowSkipException
from airflow.providers.snowflake.hooks.snowflake import SnowflakeHook
from airflow.sdk import Variable, dag, task
from airflow.utils.trigger_rule import TriggerRule

DBT_VENV_BIN = "/opt/dbt_venv/bin/dbt"
SNOWFLAKE_CONN_ID = "snowflake_default"
# Overridable via Airflow Variable so this DAG works whether the repo is
# mounted at the path this default assumes or somewhere else.
DEFAULT_DBT_PROJECT_DIR = "/opt/airflow/workday-fivetran-dbt-snowflake/dbt_project"


def _dbt_project_dir() -> str:
    return Variable.get("dbt_project_dir", default=DEFAULT_DBT_PROJECT_DIR)


def _snowflake_env() -> dict:
    """Build the SNOWFLAKE_* env vars dbt's `airflow` profile target expects,
    sourced from the snowflake_default Airflow Connection at run time.
    """
    conn = SnowflakeHook(snowflake_conn_id=SNOWFLAKE_CONN_ID).get_connection(
        SNOWFLAKE_CONN_ID
    )
    extra = conn.extra_dejson or {}

    env = dict(os.environ)
    env.update(
        {
            "SNOWFLAKE_ACCOUNT": extra.get("account", ""),
            "SNOWFLAKE_AIRFLOW_USER": conn.login or "",
            "SNOWFLAKE_AIRFLOW_PASSWORD": conn.password or "",
            "SNOWFLAKE_ROLE": extra.get("role", "DBT_TRANSFORMER"),
            "SNOWFLAKE_DATABASE": extra.get("database", "HR_ANALYTICS"),
            "SNOWFLAKE_WAREHOUSE": extra.get("warehouse", "WH_DBT_TRANSFORM"),
            "SNOWFLAKE_AIRFLOW_SCHEMA": extra.get("schema", "orchestrated"),
            "DBT_PROFILES_DIR": _dbt_project_dir(),
        }
    )
    return env


def _run_dbt(*args: str) -> None:
    """Run one dbt command in the isolated dbt venv, streaming output into
    the Airflow task log, and raising (failing the task) on a non-zero exit.
    """
    cmd = [DBT_VENV_BIN, *args, "--target", "airflow"]
    project_dir = _dbt_project_dir()
    result = subprocess.run(
        cmd,
        cwd=project_dir,
        env=_snowflake_env(),
        capture_output=True,
        text=True,
        check=False,
    )
    print(result.stdout)
    if result.returncode != 0:
        print(result.stderr)
        raise RuntimeError(
            f"dbt {' '.join(args)} failed (exit {result.returncode}) in {project_dir}"
        )


@dag(
    dag_id="workday_hr_analytics",
    description="Workday -> Fivetran -> Snowflake RAW -> dbt staging -> "
    "snapshot -> marts -> tests",
    schedule="0 6 * * *",  # daily 06:00 — matches the HCM/Position sync
    # cadence documented in docs/architecture.md Sec. 2; tighten per-domain
    # if you split this into separate DAGs later.
    start_date=datetime(2026, 1, 1),
    catchup=False,
    tags=["workday", "dbt", "snowflake", "hr-analytics"],
    default_args={"retries": 1},
)
def workday_hr_analytics():
    """See module docstring for the full pipeline shape and prerequisites."""

    @task
    def dbt_deps() -> None:
        _run_dbt("deps")

    @task
    def check_workday_source_freshness() -> None:
        """Gate on Fivetran having actually synced recently, instead of
        polling Fivetran's API directly — reuses the freshness blocks
        already declared in models/staging/workday/_workday__sources.yml
        (dbt's own recommended pattern; see docs/architecture.md Sec. 7).

        Demo caveat: this repo's sample data was loaded once via
        snowflake/02_load_sample_data.sql, not by a live, continuously
        syncing Fivetran connector — so _fivetran_synced will legitimately
        go stale and this check WILL start failing more than
        error_after (24h) past that load. That's correct behavior for a
        real pipeline; for the demo it's caught and turned into a skip
        (not a silent pass) so the rest of the DAG still runs for
        portfolio/demo purposes. Remove the try/except below once this is
        pointed at a real, continuously-syncing Fivetran connector.
        """
        try:
            _run_dbt("source", "freshness", "--select", "source:workday")
        except RuntimeError as exc:
            raise AirflowSkipException(
                "Source freshness check failed — expected once the demo's "
                "one-time sample-data load (snowflake/02_load_sample_data.sql) "
                "is older than the error_after threshold in "
                "_workday__sources.yml, since no live Fivetran connector is "
                "running against it. Point this at a real connector to make "
                "this a hard failure again."
            ) from exc

    @task(trigger_rule=TriggerRule.NONE_FAILED)
    def dbt_seed() -> None:
        # NONE_FAILED (not the default ALL_SUCCESS): must still run even
        # when check_workday_source_freshness was skipped rather than
        # succeeded — see that task's docstring. Only a genuine upstream
        # failure should stop the pipeline here.
        _run_dbt("seed")

    @task
    def dbt_run_staging() -> None:
        _run_dbt("run", "--select", "staging")

    @task
    def dbt_snapshot() -> None:
        # snap_workers reads stg_workday__workers — must run after
        # dbt_run_staging, not before (see module docstring).
        _run_dbt("snapshot")

    @task
    def dbt_run_marts() -> None:
        _run_dbt("run", "--exclude", "staging")

    @task
    def dbt_test() -> None:
        _run_dbt("test")

    (
        dbt_deps()
        >> check_workday_source_freshness()
        >> dbt_seed()
        >> dbt_run_staging()
        >> dbt_snapshot()
        >> dbt_run_marts()
        >> dbt_test()
    )


workday_hr_analytics()
