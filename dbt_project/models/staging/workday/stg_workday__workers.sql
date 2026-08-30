with source as (

    select * from {{ source('workday', 'workday_workers') }}
    where not coalesce(_fivetran_deleted, false)

),

renamed as (

    select
        employee_id,
        first_name,
        last_name,
        hire_date,
        termination_date,
        worker_status,
        position_id,
        department_id,
        manager_employee_id,
        location_id,
        compensation_band,
        last_modified as source_last_modified,
        _fivetran_synced
    from source

)

select * from renamed
