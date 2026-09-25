import datetime

import streamlit as st

from lib import queries

st.set_page_config(page_title="Employee Time Travel", layout="wide")
st.title("Employee Time Travel")
st.caption(
    "dim_employee is SCD Type 2: each change to job, department, manager, "
    "compensation band or status adds a new version (valid_from → valid_to). "
    "Pick a date to see the version in effect at the end of that day."
)

employees = queries.employee_list()
if employees.empty:
    st.info("No employees found in dim_employee.")
    st.stop()

labels = dict(
    zip(employees.employee_id, employees.full_name + " (" + employees.employee_id + ")")
)

col1, col2 = st.columns([2, 1])
employee_id = col1.selectbox(
    "Employee", employees.employee_id, format_func=labels.get
)
as_of_date = col2.date_input("As of", value=datetime.date.today())

history = queries.employee_history(employee_id)
as_of = queries.employee_as_of(employee_id, as_of_date)

st.subheader(f"As of {as_of_date:%Y-%m-%d}")
if as_of.empty:
    first_valid_from = history.valid_from.min()
    st.info(
        "No version of this employee was in effect on that date. "
        f"History starts at {first_valid_from:%Y-%m-%d %H:%M}."
    )
else:
    row = as_of.iloc[0]
    col1, col2, col3, col4 = st.columns(4)
    col1.metric("Job title", row.job_title or "–")
    col2.metric("Department", row.department_name or "–")
    col3.metric("Status", row.worker_status or "–")
    col4.metric("Comp band", row.compensation_band or "–")
    valid_to = (
        "current" if row.is_current else f"{row.valid_to:%Y-%m-%d %H:%M}"
    )
    st.caption(
        f"Version valid from {row.valid_from:%Y-%m-%d %H:%M} to {valid_to} · "
        f"location {row.location_name or '–'} · manager "
        f"{row.manager_employee_id or '–'}"
    )

st.subheader("Full history")
st.caption(f"{len(history)} version(s), oldest first.")
st.dataframe(
    history,
    hide_index=True,
    column_config={
        "employee_id": None,
        "full_name": None,
        "valid_from": st.column_config.DatetimeColumn("Valid from"),
        "valid_to": st.column_config.DatetimeColumn("Valid to"),
        "is_current": st.column_config.CheckboxColumn("Current"),
    },
)
