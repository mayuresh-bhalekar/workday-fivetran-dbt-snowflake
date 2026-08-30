with source as (

    select * from {{ source('workday', 'workday_locations') }}
    where not coalesce(_fivetran_deleted, false)

),

renamed as (

    select
        location_id,
        location_name,
        country,
        time_zone,
        _fivetran_synced
    from source

)

select * from renamed
