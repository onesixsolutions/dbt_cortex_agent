{{ config(
    materialized='view',
    alias='top_level_alias',
    meta={'alias': 'meta_alias'}
) }}
{#- get_package_config: when an option is set both at the top level and under `meta`, meta wins.
    `alias` is used because it is a native config key on every dbt version, so this model
    parses on dbt v2, which rejects unknown top-level keys. -#}
{% if execute %}
{{ assert_equal('meta wins over the top-level key', dbt_cortex_agent.get_package_config('alias'), 'meta_alias') }}
{% endif %}
select 1 as ok
