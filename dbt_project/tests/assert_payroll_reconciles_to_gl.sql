-- Singular test: for every cost center and pay period, fact_pay's total
-- Earnings must equal fact_gl_transactions' payroll-sourced Salaries Expense
-- posting for that same cost center and date. This is the acceptance test
-- docs/architecture.md calls out under "Success metrics" ("fact_pay
-- reconciles to Workday's own payroll register total") extended to the GL.
-- dbt convention: a singular test should return ZERO rows to pass.

with payroll_earnings as (

    select
        dim_cost_center.cost_center_id,
        fact_pay.pay_period_end_date,
        sum(fact_pay.amount) as total_earnings
    from {{ ref('fact_pay') }} as fact_pay
    inner join {{ ref('dim_employee') }} as dim_employee
        on fact_pay.employee_key = dim_employee.employee_key
    inner join {{ ref('dim_cost_center') }} as dim_cost_center
        on dim_employee.department_id = dim_cost_center.department_id
    where fact_pay.code_type = 'Earning'
    group by 1, 2

),

gl_salaries_expense as (

    select
        cost_center_id,
        transaction_date,
        sum(amount) as total_salaries_expense
    from {{ ref('fact_gl_transactions') }}
    where
        source_system = 'PAYROLL'
        and account_type = 'Expense'
    group by 1, 2

)

select
    payroll_earnings.cost_center_id,
    payroll_earnings.pay_period_end_date,
    payroll_earnings.total_earnings,
    gl_salaries_expense.total_salaries_expense
from payroll_earnings
left join gl_salaries_expense
    on
        payroll_earnings.cost_center_id = gl_salaries_expense.cost_center_id
        and payroll_earnings.pay_period_end_date
        = gl_salaries_expense.transaction_date
where
    gl_salaries_expense.total_salaries_expense is null
    or abs(
        payroll_earnings.total_earnings
        - gl_salaries_expense.total_salaries_expense
    ) > 0.01
