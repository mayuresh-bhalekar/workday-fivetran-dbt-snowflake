import altair as alt
import streamlit as st

from lib import queries

st.set_page_config(page_title="Payroll ↔ GL Reconciliation", layout="wide")
st.title("Payroll ↔ GL Reconciliation")
st.caption(
    "Payroll earnings (fact_pay, code_type = 'Earning') per cost center and pay "
    "period vs Salaries Expense posted to the GL (fact_gl_transactions, "
    "source_system = 'PAYROLL', account_type = 'Expense'). Same logic as the dbt "
    "test assert_payroll_reconciles_to_gl."
)

recon = queries.payroll_gl_reconciliation()
if recon.empty:
    st.info("No payroll or GL payroll postings found.")
    st.stop()

unreconciled = recon[recon.is_unreconciled]
payroll_total = float(recon.payroll_earnings.sum())
gl_total = float(recon.gl_salaries_expense.sum())

col1, col2, col3, col4 = st.columns(4)
col1.metric("Payroll earnings", f"${payroll_total:,.2f}")
col2.metric("GL salaries expense", f"${gl_total:,.2f}")
col3.metric("Variance", f"${payroll_total - gl_total:,.2f}")
col4.metric("Unreconciled rows", f"{len(unreconciled)} of {len(recon)}")

if unreconciled.empty:
    st.success("Every cost center and pay period reconciles (within $0.01).")
else:
    st.warning(
        f"{len(unreconciled)} cost center / pay period rows don't reconcile."
    )

st.subheader("Payroll vs GL by cost center")
by_cost_center = (
    recon.groupby(["cost_center_id", "department_name"], dropna=False)[
        ["payroll_earnings", "gl_salaries_expense"]
    ]
    .sum()
    .reset_index()
    .melt(
        id_vars=["cost_center_id", "department_name"],
        var_name="source",
        value_name="amount",
    )
)
by_cost_center["source"] = by_cost_center.source.map(
    {"payroll_earnings": "Payroll earnings", "gl_salaries_expense": "GL salaries expense"}
)
chart = (
    alt.Chart(by_cost_center)
    .mark_bar()
    .encode(
        x=alt.X("cost_center_id:N", title="Cost center"),
        y=alt.Y("amount:Q", title="Amount ($)"),
        color=alt.Color("source:N", title=None),
        xOffset="source:N",
        tooltip=[
            "cost_center_id:N",
            "department_name:N",
            "source:N",
            alt.Tooltip("amount:Q", format="$,.2f"),
        ],
    )
)
st.altair_chart(chart, width="stretch")

st.subheader("Detail by cost center and pay period")


def _highlight(row):
    style = "background-color: rgba(255, 75, 75, 0.2)" if row.is_unreconciled else ""
    return [style] * len(row)


st.dataframe(
    recon.style.apply(_highlight, axis=1),
    hide_index=True,
    column_config={
        "cost_center_id": "Cost center",
        "cost_center_name": "Cost center name",
        "department_name": "Department",
        "pay_period_end_date": st.column_config.DateColumn("Pay period end"),
        "payroll_earnings": st.column_config.NumberColumn(
            "Payroll earnings", format="dollar"
        ),
        "gl_salaries_expense": st.column_config.NumberColumn(
            "GL salaries expense", format="dollar"
        ),
        "variance": st.column_config.NumberColumn("Variance", format="dollar"),
        "is_unreconciled": st.column_config.CheckboxColumn("Unreconciled"),
    },
)
