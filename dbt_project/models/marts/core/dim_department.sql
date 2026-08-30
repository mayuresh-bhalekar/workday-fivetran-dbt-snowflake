{{ config(materialized='table') }}

-- Conformed dimension, SCD Type 1 (overwrite). Grain: one row per department.

select
    department_id,
    department_name,
    cost_center,
    division
from {{ ref('stg_workday__departments') }}
