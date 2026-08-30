{% macro signed_amount(amount_column, code_type_column) -%}
    {#- Payroll convention: Earnings are positive, Deductions are stored
        negative already in this source, but this macro normalizes the sign
        in case an upstream feed ever sends deductions as positive amounts. -#}
    case
        when {{ code_type_column }} = 'Deduction' and {{ amount_column }} > 0
            then -1 * {{ amount_column }}
        else {{ amount_column }}
    end
{%- endmacro %}
