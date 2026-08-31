with source as (

    select * from {{ source('workday', 'workday_cost_centers') }}
    where not coalesce(_fivetran_deleted, false)

),

renamed as (

    select
        cost_center_id,
        cost_center_name,
        department_id,
        _fivetran_synced
    from source

)

select * from renamed
