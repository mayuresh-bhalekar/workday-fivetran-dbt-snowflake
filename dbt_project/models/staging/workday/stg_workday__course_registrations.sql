with source as (

    select * from {{ source('workday', 'workday_course_registrations') }}
    where not coalesce(_fivetran_deleted, false)

),

renamed as (

    select
        registration_id,
        student_id,
        course_id,
        course_name,
        academic_period_id,
        credit_hours,
        grade,
        registration_status,
        registration_date,
        _fivetran_synced
    from source

)

select * from renamed
