with source as (

    select * from {{ source('workday', 'workday_time_entries') }}
    where not coalesce(_fivetran_deleted, false)

),

renamed as (

    select
        time_entry_id,
        employee_id,
        entry_date,
        hours_worked,
        overtime_hours,
        time_type,
        _fivetran_synced
    from source

)

select * from renamed
