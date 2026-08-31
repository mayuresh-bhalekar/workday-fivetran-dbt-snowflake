{{
    config(
        materialized='incremental',
        unique_key='enrollment_id',
        cluster_by=['effective_date'],
        incremental_strategy='merge'
    )
}}

-- Semi-additive fact (periodic snapshot semantics). Grain: one row per
-- worker per plan per enrollment effective date. Do NOT sum coverage_amount
-- across time periods — use point-in-time / period-end aggregation instead.

with enrollments as (

    select * from {{ ref('stg_workday__benefits_enrollment') }} as src

    {% if is_incremental() %}
        where src._fivetran_synced > (
            select coalesce(max(this_tbl._fivetran_synced), '1900-01-01')
            from {{ this }} as this_tbl
        )
    {% endif %}

),

dim_employee_current as (

    select * from {{ ref('dim_employee') }}
    where is_current

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['enrollments.enrollment_id']) }}
            as benefits_enrollment_key,
        enrollments.enrollment_id,
        enrollments.employee_id,
        dim_employee_current.employee_key,
        enrollments.plan_name,
        enrollments.plan_type,
        enrollments.coverage_level,
        enrollments.coverage_amount,
        enrollments.effective_date,
        {{ dbt_utils.generate_surrogate_key(['enrollments.effective_date']) }}
            as date_key,
        enrollments._fivetran_synced
    from enrollments
    left join dim_employee_current
        on enrollments.employee_id = dim_employee_current.employee_id

)

select * from final
