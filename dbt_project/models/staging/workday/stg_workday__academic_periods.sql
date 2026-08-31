with source as (

    select * from {{ source('workday', 'workday_academic_periods') }}
    where not coalesce(_fivetran_deleted, false)

),

renamed as (

    select
        academic_period_id,
        period_name,
        start_date,
        end_date,
        period_type,
        academic_year,
        _fivetran_synced
    from source

)

select * from renamed
