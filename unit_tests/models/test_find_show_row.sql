{{ config(materialized='view') }}
{#- find_show_row: exact-name matching over SHOW ... LIKE results, and the LIVE-version rule. -#}
{% if execute %}
{%- set rows = [
  {'name': 'SALESXAGENT', 'search_column': 'WRONG'},
  {'name': 'SALES_AGENT', 'search_column': 'RIGHT'},
  {'name': 'SALES_AGENT_V2', 'search_column': 'WRONG'}
] -%}
{{ assert_equal('find: exact match returns that row', dbt_cortex_agent.find_show_row(rows, 'SALES_AGENT')['search_column'], 'RIGHT') }}
{{ assert_equal('find: an identifier in a different case still matches', dbt_cortex_agent.find_show_row(rows, 'sales_agent')['search_column'], 'RIGHT') }}
{{ assert_true('find: a name that only matches through the LIKE wildcard is rejected', dbt_cortex_agent.find_show_row([rows[0]], 'SALES_AGENT') is none) }}
{{ assert_true('find: a longer name with the same prefix is rejected', dbt_cortex_agent.find_show_row([rows[2]], 'SALES_AGENT') is none) }}
{{ assert_true('find: no rows returns none', dbt_cortex_agent.find_show_row([], 'SALES_AGENT') is none) }}
{{ assert_equal('find: the first match wins when names differ only by case',
    dbt_cortex_agent.find_show_row([{'name': 'Sales_Agent', 'n': 1}, {'name': 'SALES_AGENT', 'n': 2}], 'SALES_AGENT')['n'], 1) }}
{% endif %}
select 1 as ok
