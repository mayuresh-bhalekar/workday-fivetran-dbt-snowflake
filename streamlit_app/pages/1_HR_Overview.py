import altair as alt
import pandas as pd
import streamlit as st

from lib import queries

st.set_page_config(page_title="HR Overview", layout="wide")
st.title("HR Overview")
st.caption("Current version of each employee (dim_employee where is_current).")

options = queries.hr_filter_options()
with st.sidebar:
    st.header("Filters")
    departments = st.multiselect(
        "Department", sorted(options.department_name.dropna().unique())
    )
    locations = st.multiselect(
        "Location", sorted(options.location_name.dropna().unique())
    )

kpis = queries.hr_kpis(departments, locations).iloc[0]
col1, col2, col3, col4 = st.columns(4)
col1.metric("Active headcount", f"{int(kpis.active_headcount or 0):,}")
col2.metric("On leave", f"{int(kpis.on_leave or 0):,}")
col3.metric("Terminated", f"{int(kpis.terminated or 0):,}")
col4.metric(
    "Avg tenure (years)",
    "–" if pd.isna(kpis.avg_tenure_years) else f"{float(kpis.avg_tenure_years):.1f}",
    help="Active and on-leave employees, hire date to today.",
)

st.subheader("Hires vs terminations by month")
events = queries.hires_vs_terminations_by_month(departments, locations)
if events.empty:
    st.info("No hires or terminations for the selected filters.")
else:
    chart = (
        alt.Chart(events)
        .mark_bar()
        .encode(
            x=alt.X("yearmonth(event_month):T", title="Month"),
            y=alt.Y("employee_count:Q", title="Employees"),
            color=alt.Color("event_type:N", title=None),
            xOffset="event_type:N",
            tooltip=[
                alt.Tooltip("yearmonth(event_month):T", title="Month"),
                alt.Tooltip("event_type:N", title="Event"),
                alt.Tooltip("employee_count:Q", title="Employees"),
            ],
        )
    )
    st.altair_chart(chart, width="stretch")

left, right = st.columns(2)
for column, dimension, title in (
    (left, "department_name", "Active headcount by department"),
    (right, "location_name", "Active headcount by location"),
):
    with column:
        st.subheader(title)
        data = queries.headcount_by(dimension, departments, locations)
        if data.empty:
            st.info("No active employees for the selected filters.")
            continue
        chart = (
            alt.Chart(data)
            .mark_bar()
            .encode(
                x=alt.X("active_headcount:Q", title="Active headcount"),
                y=alt.Y(f"{dimension}:N", title=None, sort="-x"),
                tooltip=[f"{dimension}:N", "active_headcount:Q"],
            )
        )
        st.altair_chart(chart, width="stretch")
