{{ config(materialized='view', alias='only_top_level') }}
{#- get_package_config: a model with no `meta` at all. -#}
{% if execute %}
{{ assert_equal('top-level key is read when the model has no meta', dbt_cortex_agent.get_package_config('alias'), 'only_top_level') }}
{{ assert_equal('default is returned when the model has no meta', dbt_cortex_agent.get_package_config('comment', default='dflt'), 'dflt') }}
{{ assert_equal('list default is returned when the model has no meta', dbt_cortex_agent.get_package_config('agent_grants', default=[]), []) }}
{% endif %}
select 1 as ok
