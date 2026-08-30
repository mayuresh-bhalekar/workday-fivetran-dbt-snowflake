with source as (

    select * from {{ source('workday', 'workday_benefits_enrollment') }}
    where not coalesce(_fivetran_deleted, false)

),

renamed as (

    select
        enrollment_id,
        employee_id,
        plan_name,
        plan_type,
        coverage_level,
        coverage_amount,
        effective_date,
        _fivetran_synced
    from source

)

select * from renamed
