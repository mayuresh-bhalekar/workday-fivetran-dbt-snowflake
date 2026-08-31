{{ config(materialized='table') }}

-- Conformed dimension, SCD Type 1 (overwrite). Grain: one row per program.

select
    program_id,
    program_name,
    degree_level,
    academic_unit,
    credit_hours_required
from {{ ref('stg_workday__programs') }}
