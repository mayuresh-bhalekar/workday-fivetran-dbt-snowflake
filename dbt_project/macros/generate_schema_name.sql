{% macro generate_schema_name(custom_schema_name, node) -%}

    {#- In dev, prefix with the target schema (personal sandbox) so multiple
        developers don't collide. In prod/ci, use the custom schema exactly
        as configured in dbt_project.yml (e.g. MARTS_CORE, not
        PROD_marts_core) to match the schema layout documented in
        docs/architecture.md. -#}

    {%- set default_schema = target.schema -%}

    {%- if target.name == 'prod' or target.name == 'ci' -%}
        {{ custom_schema_name | trim }}
    {%- elif custom_schema_name is none -%}
        {{ default_schema }}
    {%- else -%}
        {{ default_schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}

{%- endmacro %}
