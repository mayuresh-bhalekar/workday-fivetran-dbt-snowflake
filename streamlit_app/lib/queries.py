"""All SQL the app runs, in one place.

- Only schema names are interpolated (resolved + validated in connection.py).
- Every user-selected value is a qmark bind parameter (?), never formatted in.
- Multi-select filters are passed as one JSON array string; an empty array
  means "no filter".
- Metric definitions mirror the meta.metrics blocks in dbt_project/models/marts
  (e.g. total_pay = sum(fact_pay.amount)) so numbers match Lightdash.
"""

import json

import streamlit as st

from lib.connection import (
    get_session,
    is_expired_session_error,
    marts_schema,
    reset_session,
)


@st.cache_data(ttl=600, show_spinner="Querying Snowflake...")
def _run_cached(sql, params):
    df = get_session().sql(sql, params=list(params)).to_pandas()
    df.columns = [column.lower() for column in df.columns]
    return df


def run(sql, params=()):
    try:
        return _run_cached(sql, tuple(params))
    except Exception as exc:
        if not is_expired_session_error(exc):
            _show_error(sql, exc)
        # Idle session expired: reconnect once and retry.
        reset_session()
        try:
            return _run_cached(sql, tuple(params))
        except Exception as retry_exc:
            _show_error(sql, retry_exc)


def _show_error(sql, exc):
    st.error(f"Snowflake query failed:\n\n{exc}")
    with st.expander("SQL"):
        st.code(sql, language="sql")
    st.stop()


def _json_list(values):
    return json.dumps(sorted(values))


def _tables():
    core = marts_schema("marts_core")
    hr = marts_schema("marts_hr")
    student = marts_schema("marts_student")
    finance = marts_schema("marts_finance")
    return {
        "dim_employee": f"{core}.dim_employee",
        "fact_pay": f"{hr}.fact_pay",
        "fact_hours_worked": f"{hr}.fact_hours_worked",
        "dim_student": f"{student}.dim_student",
        "dim_cost_center": f"{finance}.dim_cost_center",
        "fact_gl_transactions": f"{finance}.fact_gl_transactions",
    }


# ---------------------------------------------------------------------------
# Landing page
# ---------------------------------------------------------------------------

def connection_status():
    return run(
        """
        select
            current_role() as current_role,
            current_warehouse() as current_warehouse,
            current_database() as current_database
        """
    )


def headline_kpis():
    t = _tables()
    return run(
        f"""
        select
            (
                select count(distinct employee_id)
                from {t['dim_employee']}
                where is_current and worker_status = 'Active'
            ) as active_headcount,
            (
                select sum(amount)
                from {t['fact_pay']}
            ) as total_pay,
            (
                select sum(total_hours)
                from {t['fact_hours_worked']}
            ) as total_hours,
            (
                select count(distinct student_id)
                from {t['dim_student']}
                where is_current and enrollment_status = 'Active'
            ) as active_students
        """
    )


# ---------------------------------------------------------------------------
# HR Overview
# ---------------------------------------------------------------------------

def hr_filter_options():
    t = _tables()
    return run(
        f"""
        select distinct
            department_name,
            location_name
        from {t['dim_employee']}
        where is_current
        """
    )


def _current_employees_sql(dim_employee):
    # Current SCD2 version of every employee, narrowed by the sidebar filters.
    return f"""
        select *
        from {dim_employee}
        where
            is_current
            and (
                array_size(parse_json(?)) = 0
                or array_contains(department_name::variant, parse_json(?))
            )
            and (
                array_size(parse_json(?)) = 0
                or array_contains(location_name::variant, parse_json(?))
            )
    """


def _filter_params(departments, locations):
    departments_json = _json_list(departments)
    locations_json = _json_list(locations)
    return (departments_json, departments_json, locations_json, locations_json)


def hr_kpis(departments, locations):
    t = _tables()
    return run(
        f"""
        with employees as ({_current_employees_sql(t['dim_employee'])})

        select
            count_if(worker_status = 'Active') as active_headcount,
            count_if(worker_status = 'Leave') as on_leave,
            count_if(worker_status = 'Terminated') as terminated,
            avg(
                case
                    when worker_status != 'Terminated'
                        then datediff('day', hire_date, current_date()) / 365.25
                end
            ) as avg_tenure_years
        from employees
        """,
        _filter_params(departments, locations),
    )


def hires_vs_terminations_by_month(departments, locations):
    t = _tables()
    return run(
        f"""
        with employees as ({_current_employees_sql(t['dim_employee'])}),

        events as (

            select date_trunc('month', hire_date) as event_month, 'Hires' as event_type
            from employees

            union all

            select date_trunc('month', termination_date), 'Terminations'
            from employees
            where termination_date is not null

        )

        select
            event_month,
            event_type,
            count(*) as employee_count
        from events
        group by 1, 2
        order by 1, 2
        """,
        _filter_params(departments, locations),
    )


def headcount_by(dimension, departments, locations):
    # dimension is chosen by the page code, never by the user.
    if dimension not in ("department_name", "location_name"):
        raise ValueError(f"Unsupported dimension: {dimension}")
    t = _tables()
    return run(
        f"""
        with employees as ({_current_employees_sql(t['dim_employee'])})

        select
            coalesce({dimension}, 'Unknown') as {dimension},
            count(distinct employee_id) as active_headcount
        from employees
        where worker_status = 'Active'
        group by 1
        order by 2 desc
        """,
        _filter_params(departments, locations),
    )


# ---------------------------------------------------------------------------
# Payroll <-> GL reconciliation
# (same logic as dbt_project/tests/assert_payroll_reconciles_to_gl.sql, but
# returns every cost center/period, not only the failures)
# ---------------------------------------------------------------------------

def payroll_gl_reconciliation():
    t = _tables()
    return run(
        f"""
        with payroll_earnings as (

            select
                dim_cost_center.cost_center_id,
                fact_pay.pay_period_end_date,
                sum(fact_pay.amount) as total_earnings
            from {t['fact_pay']} as fact_pay
            inner join {t['dim_employee']} as dim_employee
                on fact_pay.employee_key = dim_employee.employee_key
            inner join {t['dim_cost_center']} as dim_cost_center
                on dim_employee.department_id = dim_cost_center.department_id
            where fact_pay.code_type = 'Earning'
            group by 1, 2

        ),

        gl_salaries_expense as (

            select
                cost_center_id,
                transaction_date,
                sum(amount) as total_salaries_expense
            from {t['fact_gl_transactions']}
            where
                source_system = 'PAYROLL'
                and account_type = 'Expense'
            group by 1, 2

        ),

        reconciled as (

            select
                coalesce(
                    payroll_earnings.cost_center_id,
                    gl_salaries_expense.cost_center_id
                ) as cost_center_id,
                coalesce(
                    payroll_earnings.pay_period_end_date,
                    gl_salaries_expense.transaction_date
                ) as pay_period_end_date,
                coalesce(payroll_earnings.total_earnings, 0) as payroll_earnings,
                coalesce(gl_salaries_expense.total_salaries_expense, 0)
                    as gl_salaries_expense
            from payroll_earnings
            full outer join gl_salaries_expense
                on
                    payroll_earnings.cost_center_id = gl_salaries_expense.cost_center_id
                    and payroll_earnings.pay_period_end_date
                    = gl_salaries_expense.transaction_date

        )

        select
            reconciled.cost_center_id,
            dim_cost_center.cost_center_name,
            dim_cost_center.department_name,
            reconciled.pay_period_end_date,
            reconciled.payroll_earnings,
            reconciled.gl_salaries_expense,
            reconciled.payroll_earnings - reconciled.gl_salaries_expense as variance,
            abs(reconciled.payroll_earnings - reconciled.gl_salaries_expense) > 0.01
                as is_unreconciled
        from reconciled
        left join {t['dim_cost_center']} as dim_cost_center
            on reconciled.cost_center_id = dim_cost_center.cost_center_id
        order by reconciled.pay_period_end_date, reconciled.cost_center_id
        """
    )


# ---------------------------------------------------------------------------
# Employee time travel (dim_employee SCD2)
# ---------------------------------------------------------------------------

def employee_list():
    t = _tables()
    return run(
        f"""
        select
            employee_id,
            full_name
        from {t['dim_employee']}
        where is_current
        order by full_name
        """
    )


_EMPLOYEE_HISTORY_COLUMNS = """
    employee_id,
    full_name,
    worker_status,
    job_title,
    management_level,
    compensation_band,
    department_name,
    location_name,
    manager_employee_id,
    hire_date,
    termination_date,
    valid_from,
    valid_to,
    is_current
"""


def employee_as_of(employee_id, as_of_date):
    # The version in effect at the end of as_of_date.
    t = _tables()
    return run(
        f"""
        select {_EMPLOYEE_HISTORY_COLUMNS}
        from {t['dim_employee']}
        where
            employee_id = ?
            and valid_from < dateadd('day', 1, ?::date)
            and (valid_to is null or valid_to >= dateadd('day', 1, ?::date))
        """,
        (employee_id, as_of_date.isoformat(), as_of_date.isoformat()),
    )


def employee_history(employee_id):
    t = _tables()
    return run(
        f"""
        select {_EMPLOYEE_HISTORY_COLUMNS}
        from {t['dim_employee']}
        where employee_id = ?
        order by valid_from
        """,
        (employee_id,),
    )
