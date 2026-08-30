with source as (

    select * from {{ source('workday', 'workday_departments') }}
    where not coalesce(_fivetran_deleted, false)

),

renamed as (

    select
        department_id,
        department_name,
        cost_center,
        division,
        _fivetran_synced
    from source

)

select * from renamed
