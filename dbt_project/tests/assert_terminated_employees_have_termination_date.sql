-- Singular test: a worker with status 'Terminated' must carry a termination_date.
-- Catches upstream Workday/Fivetran data-quality drift before it reaches BI.

select
    employee_id,
    worker_status,
    termination_date
from {{ ref('dim_employee') }}
where worker_status = 'Terminated'
  and termination_date is null
  and is_current
