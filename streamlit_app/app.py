"""Workday HR Analytics: landing page.

Run locally from the repo root:
    streamlit run streamlit_app/app.py
"""

import streamlit as st

from lib import queries
from lib.connection import marts_schema

st.set_page_config(page_title="Workday HR Analytics", layout="wide")

st.title("Workday HR Analytics")
st.caption(
    "Live from the dbt marts in Snowflake: Workday → Fivetran → dbt → Snowflake."
)

status = queries.connection_status().iloc[0]
st.caption(
    f"Connected as role **{status.current_role}** · "
    f"warehouse **{status.current_warehouse}** · "
    f"database **{status.current_database}** · "
    f"core schema **{marts_schema('marts_core')}**"
)

kpis = queries.headline_kpis().iloc[0]

col1, col2, col3, col4 = st.columns(4)
col1.metric("Active headcount", f"{int(kpis.active_headcount or 0):,}")
col2.metric(
    "Total pay (net)",
    f"${float(kpis.total_pay or 0):,.0f}",
    help="sum(fact_pay.amount): earnings minus deductions (total_pay metric).",
)
col3.metric("Hours worked", f"{float(kpis.total_hours or 0):,.0f}")
col4.metric("Active students", f"{int(kpis.active_students or 0):,}")

st.divider()
st.markdown(
    """
**Pages**

- **HR Overview**: headcount, hires vs terminations, tenure, and headcount by
  department and location.
- **Payroll ↔ GL Reconciliation**: payroll earnings per cost center and pay
  period against Salaries Expense posted to the general ledger.
- **Employee Time Travel**: an employee's job, department and status as of any
  date, from the SCD2 `dim_employee`.
"""
)
