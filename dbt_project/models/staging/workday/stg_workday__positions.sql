with source as (

    select * from {{ source('workday', 'workday_positions') }}
    where not coalesce(_fivetran_deleted, false)

),

renamed as (

    select
        position_id,
        job_title,
        job_family,
        management_level,
        fte,
        _fivetran_synced
    from source

)

select * from renamed
