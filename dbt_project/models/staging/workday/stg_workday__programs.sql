with source as (

    select * from {{ source('workday', 'workday_programs') }}
    where not coalesce(_fivetran_deleted, false)

),

renamed as (

    select
        program_id,
        program_name,
        degree_level,
        academic_unit,
        credit_hours_required,
        _fivetran_synced
    from source

)

select * from renamed
