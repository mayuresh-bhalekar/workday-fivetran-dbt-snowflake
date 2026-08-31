with source as (

    select * from {{ source('workday', 'workday_students') }}
    where not coalesce(_fivetran_deleted, false)

),

renamed as (

    select
        student_id,
        first_name,
        last_name,
        birth_date,
        enrollment_status,
        program_id,
        admit_term_id,
        expected_grad_term_id,
        last_modified as source_last_modified,
        _fivetran_synced
    from source

)

select * from renamed
