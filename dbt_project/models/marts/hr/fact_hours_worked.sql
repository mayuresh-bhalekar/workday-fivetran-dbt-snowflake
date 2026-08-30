{{
    config(
        materialized='incremental',
        unique_key='time_entry_id',
        cluster_by=['entry_date'],
        incremental_strategy='merge'
    )
}}

-- Atomic fact. Grain: one row per worker per time entry per day.
-- Additive measures: hours_worked, overtime_hours.

with time_entries as (

    select * from {{ ref('stg_workday__time_entries') }}

    {% if is_incremental() %}
    where _fivetran_synced > (select coalesce(max(_fivetran_synced), '1900-01-01') from {{ this }})
    {% endif %}

),

dim_employee_current as (

    select * from {{ ref('dim_employee') }}
    where is_current

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['time_entries.time_entry_id']) }} as hours_worked_key,
        time_entries.time_entry_id,
        time_entries.employee_id,
        dim_employee_current.employee_key,
        time_entries.entry_date,
        {{ dbt_utils.generate_surrogate_key(['time_entries.entry_date']) }} as date_key,
        time_entries.time_type,
        time_entries.hours_worked,
        time_entries.overtime_hours,
        (time_entries.hours_worked + time_entries.overtime_hours) as total_hours,
        time_entries._fivetran_synced
    from time_entries
    left join dim_employee_current on time_entries.employee_id = dim_employee_current.employee_id

)

select * from final
