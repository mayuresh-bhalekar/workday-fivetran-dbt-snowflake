{{
    config(
        materialized='incremental',
        unique_key='registration_id',
        cluster_by=['academic_period_id'],
        incremental_strategy='merge'
    )
}}

-- Atomic fact. Grain: one row per student per course registration per
-- academic period. Additive measure: credit_hours (additive within a period
-- — do not sum across periods to get "total credits," use a cumulative
-- snapshot pattern for that instead).

with registrations as (

    select * from {{ ref('stg_workday__course_registrations') }}

    {% if is_incremental() %}
        where _fivetran_synced > (
            select coalesce(max(_fivetran_synced), '1900-01-01')
            from {{ this }}
        )
    {% endif %}

),

dim_student_current as (

    select * from {{ ref('dim_student') }}
    where is_current

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key([
            'registrations.registration_id'
        ]) }}
            as enrollment_key,
        registrations.registration_id,
        registrations.student_id,
        dim_student_current.student_key,
        registrations.course_id,
        registrations.course_name,
        registrations.academic_period_id,
        registrations.credit_hours,
        registrations.grade,
        registrations.registration_status,
        registrations.registration_date,
        registrations._fivetran_synced
    from registrations
    left join dim_student_current
        on registrations.student_id = dim_student_current.student_id

)

select * from final
