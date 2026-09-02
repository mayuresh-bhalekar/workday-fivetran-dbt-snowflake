# Extends the base Airflow image this project already runs (apache/airflow:3.3.1)
# with an isolated virtualenv for dbt. dbt-core pins its own versions of click,
# jinja2, protobuf, etc. that can conflict with Airflow's own pins — installing
# dbt-snowflake into Airflow's own site-packages (e.g. via _PIP_ADDITIONAL_REQUIREMENTS)
# is a well-known way to break the Airflow webserver/scheduler. A dedicated venv
# avoids that entirely; the DAG calls /opt/dbt_venv/bin/dbt explicitly.
#
# Pinned to 3.3.1, not 3.0.0: the 3.0.0 dag-processor has a wall-clock vs
# psutil start_time bug (apache/airflow#49689, fixed in #49868) that SIGKILLs
# every parse attempt after a host sleep/wake cycle, eventually dropping the
# DAG from the UI entirely. Fixed in 3.0.1+; 3.3.1 is the current stable line
# (3.0.x is no longer patched) and picks up all later dag-processor stability
# fixes too. Don't downgrade below 3.0.1 without re-checking that issue.
#
# Build (from the airflow/ directory):
#   docker build -t workday-hr-airflow:latest -f Dockerfile ..
# See ../README.md (airflow/README.md) for wiring this into an existing
# docker-compose-based Airflow deployment.

ARG AIRFLOW_IMAGE_NAME=apache/airflow:3.3.1
FROM ${AIRFLOW_IMAGE_NAME}

# Match the dbt-snowflake version pinned everywhere else in this repo
# (dbt_project/dbt_project.yml comment, .github/workflows/dbt_ci.yml, README quickstart).
ARG DBT_SNOWFLAKE_VERSION=1.8.*

# Everything below runs as root at build time so it's independent of whatever
# UID docker-compose runs the container as (this repo's compose file already
# overrides to ${AIRFLOW_UID:-50000}:0) — the final chown makes the venv
# usable by that runtime user regardless.
USER root
# python3-venv occasionally needed for dbt's compiled deps on a fresh Debian
# base; harmless no-op if already present in the upstream image.
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3-venv \
    && rm -rf /var/lib/apt/lists/* \
    && python -m venv /opt/dbt_venv \
    && /opt/dbt_venv/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/dbt_venv/bin/pip install --no-cache-dir "dbt-snowflake==${DBT_SNOWFLAKE_VERSION}" \
    && chown -R 50000:0 /opt/dbt_venv \
    && chmod -R g=u /opt/dbt_venv

USER airflow
