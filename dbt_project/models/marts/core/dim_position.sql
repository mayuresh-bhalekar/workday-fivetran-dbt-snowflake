{{ config(materialized='table') }}

-- Conformed dimension, SCD Type 1 (overwrite). Grain: one row per position.

select
    position_id,
    job_title,
    job_family,
    management_level,
    fte
from {{ ref('stg_workday__positions') }}
