{{ config(materialized='table') }}

-- Conformed dimension, SCD Type 1 (overwrite). Grain: one row per location.

select
    location_id,
    location_name,
    country,
    time_zone
from {{ ref('stg_workday__locations') }}
