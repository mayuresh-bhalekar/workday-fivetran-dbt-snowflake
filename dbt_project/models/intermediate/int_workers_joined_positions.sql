-- Business-logic join: current worker snapshot enriched with position,
-- department, and location attributes. Not BI-facing — feeds dim_employee.

with workers as (

    select * from {{ ref('stg_workday__workers') }}

),

positions as (

    select * from {{ ref('stg_workday__positions') }}

),

departments as (

    select * from {{ ref('stg_workday__departments') }}

),

locations as (

    select * from {{ ref('stg_workday__locations') }}

),

joined as (

    select
        workers.employee_id,
        workers.first_name,
        workers.last_name,
        workers.hire_date,
        workers.termination_date,
        workers.worker_status,
        workers.manager_employee_id,
        workers.compensation_band,
        workers.source_last_modified,
        workers.position_id,
        positions.job_title,
        positions.job_family,
        positions.management_level,
        positions.fte,
        workers.department_id,
        departments.department_name,
        departments.cost_center,
        departments.division,
        workers.location_id,
        locations.location_name,
        locations.country,
        locations.time_zone
    from workers
    left join positions on workers.position_id = positions.position_id
    left join departments on workers.department_id = departments.department_id
    left join locations on workers.location_id = locations.location_id

)

select * from joined
