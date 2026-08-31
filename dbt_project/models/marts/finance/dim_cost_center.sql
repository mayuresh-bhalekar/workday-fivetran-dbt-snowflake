{{ config(materialized='table') }}

-- Conformed dimension, SCD Type 1 (overwrite). Grain: one row per cost
-- center. Denormalizes department_name from dim_department so Finance
-- reports don't need a second join back to MARTS_CORE — this is the
-- Finance <-> HCM conformance point in the bus matrix (see
-- docs/architecture.md "Conformed bus matrix").

with cost_centers as (

    select * from {{ ref('stg_workday__cost_centers') }}

),

departments as (

    select * from {{ ref('stg_workday__departments') }}

),

final as (

    select
        cost_centers.cost_center_id,
        cost_centers.cost_center_name,
        cost_centers.department_id,
        departments.department_name,
        departments.division
    from cost_centers
    left join departments
        on cost_centers.department_id = departments.department_id

)

select * from final
