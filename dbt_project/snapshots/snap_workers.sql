{% snapshot snap_workers %}

{{
    config(
        target_schema='snapshots',
        unique_key='employee_id',
        strategy='timestamp',
        updated_at='source_last_modified',
        invalidate_hard_deletes=True,
    )
}}

-- SCD Type 2 on the Worker record: captures job/department/manager/comp
-- history over time so facts can be joined to "the dim_employee row that
-- was true as of that transaction date" rather than only the current state.
-- Run `dbt snapshot` on a schedule immediately after each Fivetran sync.

    select * from {{ ref('stg_workday__workers') }}

{% endsnapshot %}
