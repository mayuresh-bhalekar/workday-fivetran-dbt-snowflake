-- Singular test: worked hours must never be negative.
-- dbt convention: a singular test should return ZERO rows to pass.

select
    time_entry_id,
    employee_id,
    hours_worked,
    overtime_hours
from {{ ref('fact_hours_worked') }}
where hours_worked < 0
   or overtime_hours < 0
