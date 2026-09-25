"""Snowflake session + schema resolution for the Streamlit app.

Two runtimes, one code path:
- Streamlit in Snowflake (SiS): the platform provides an active Snowpark session.
- Local: st.connection("snowflake") reads [connections.snowflake] from
  .streamlit/secrets.toml (key-pair auth as STREAMLIT_APP_USER / BI_READER).

Snowflake is the only data source. If the connection fails, the page stops
with the Snowflake error rather than falling back to anything else.
"""

import os
import re

import streamlit as st

_IDENTIFIER = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


@st.cache_resource(show_spinner="Connecting to Snowflake...")
def _create_session():
    try:
        from snowflake.snowpark.context import get_active_session

        return get_active_session()
    except Exception:
        # Not running inside Streamlit in Snowflake: use secrets.toml.
        return st.connection("snowflake").session()


def get_session():
    try:
        return _create_session()
    except Exception as exc:
        st.error(f"Could not connect to Snowflake:\n\n{exc}")
        st.stop()


def _schema_prefix():
    # Env var wins over secrets. Empty prefix = prod/ci schema names
    # (MARTS_CORE, ...); a dev target schema such as DEV_MAYURESH maps to
    # DEV_MAYURESH_MARTS_CORE, matching macros/generate_schema_name.sql.
    prefix = os.environ.get("MARTS_SCHEMA_PREFIX")
    if prefix is None:
        try:
            prefix = st.secrets.get("app", {}).get("marts_schema_prefix", "")
        except Exception:
            # No secrets.toml (e.g. Streamlit in Snowflake).
            prefix = ""
    prefix = prefix.strip()
    if prefix and not _IDENTIFIER.match(prefix):
        st.error(f"Invalid marts_schema_prefix: {prefix!r}")
        st.stop()
    return prefix.upper()


def marts_schema(name):
    """Resolve a logical mart schema (e.g. 'marts_core') to its Snowflake name."""
    prefix = _schema_prefix()
    schema = name.upper()
    return f"{prefix}_{schema}" if prefix else schema
