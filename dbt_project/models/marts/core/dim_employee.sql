{{
    config(
        materialized='table'
    )
}}

-- Conformed dimension, SCD Type 2, grain: one row per employee per
-- job/department/manager/comp version (dbt_valid_from -> dbt_valid_to).
-- Sourced from the snap_workers snapshot so history is preserved; joined to
-- position/department/location (SCD1 — current attributes only).

with workers_history as (

    select * from {{ ref('snap_workers') }}

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

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['workers_history.employee_id', 'workers_history.dbt_valid_from']) }}
            as employee_key,
        workers_history.employee_id,
        workers_history.first_name,
        workers_history.last_name,
        workers_history.first_name || ' ' || workers_history.last_name as full_name,
        workers_history.hire_date,
        workers_history.termination_date,
        workers_history.worker_status,
        workers_history.manager_employee_id,
        workers_history.compensation_band,
        workers_history.position_id,
        positions.job_title,
        positions.job_family,
        positions.management_level,
        workers_history.department_id,
        departments.department_name,
        departments.cost_center,
        departments.division,
        workers_history.location_id,
        locations.location_name,
        locations.country,
        workers_history.dbt_valid_from as valid_from,
        workers_history.dbt_valid_to as valid_to,
        (workers_history.dbt_valid_to is null) as is_current
    from workers_history
    left join positions on workers_history.position_id = positions.position_id
    left join departments on workers_history.department_id = departments.department_id
    left join locations on workers_history.location_id = locations.location_id

)

select * from final
