{{ config(materialized='table') }}

-- Generated calendar spine, no source dependency. Covers a wide static range
-- so it never needs to be extended on every run; cheap to materialize as a table.

with spine as (

    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2015-01-01' as date)",
        end_date="cast('2031-01-01' as date)"
    ) }}

),

final as (

    select
        cast(date_day as date) as date_day,
        {{ dbt_utils.generate_surrogate_key(['date_day']) }} as date_key,
        extract(year from date_day) as calendar_year,
        extract(quarter from date_day) as calendar_quarter,
        extract(month from date_day) as calendar_month,
        to_char(date_day, 'MMMM') as month_name,
        extract(week from date_day) as calendar_week,
        extract(dayofweek from date_day) as day_of_week,
        to_char(date_day, 'DY') as day_name,
        (extract(dayofweek from date_day) in (0, 6)) as is_weekend
    from spine

)

select * from final
