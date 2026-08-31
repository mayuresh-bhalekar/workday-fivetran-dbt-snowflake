{{
    config(
        materialized='table'
    )
}}

-- Conformed dimension, SCD Type 2, grain: one row per student per
-- enrollment-status/program version (dbt_valid_from -> dbt_valid_to).
-- Sourced from the snap_students snapshot so history is preserved; joined to
-- program/academic-period (SCD1 — current attributes only).

with students_history as (

    select * from {{ ref('snap_students') }}

),

programs as (

    select * from {{ ref('stg_workday__programs') }}

),

admit_terms as (

    select * from {{ ref('stg_workday__academic_periods') }}

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key([
            'students_history.student_id', 'students_history.dbt_valid_from'
        ]) }}
            as student_key,
        students_history.student_id,
        students_history.first_name,
        students_history.last_name,
        students_history.first_name || ' ' || students_history.last_name
            as full_name,
        students_history.birth_date,
        students_history.enrollment_status,
        students_history.program_id,
        programs.program_name,
        programs.degree_level,
        programs.academic_unit,
        students_history.admit_term_id,
        admit_terms.period_name as admit_term_name,
        students_history.expected_grad_term_id,
        students_history.dbt_valid_from as valid_from,
        students_history.dbt_valid_to as valid_to,
        (students_history.dbt_valid_to is null) as is_current
    from students_history
    left join programs
        on students_history.program_id = programs.program_id
    left join admit_terms
        on students_history.admit_term_id = admit_terms.academic_period_id

)

select * from final
