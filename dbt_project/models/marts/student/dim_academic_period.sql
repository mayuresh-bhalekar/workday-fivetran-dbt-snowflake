{{ config(materialized='table') }}

-- Conformed dimension, SCD Type 1 (overwrite). Grain: one row per academic
-- period (term). Distinct from dim_date: this is the term-level calendar
-- Enrollment reports against (Fall 2025, Spring 2026, ...), not a daily spine.

select
    academic_period_id,
    period_name,
    start_date,
    end_date,
    period_type,
    academic_year
from {{ ref('stg_workday__academic_periods') }}
