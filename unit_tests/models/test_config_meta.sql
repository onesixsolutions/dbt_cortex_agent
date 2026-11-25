{{ config(
    materialized='view',
    alias='config_alias',
    meta={
        'comment': 'from meta',
        'enable_versioning': false,
        'agent_grants': ['a', 'b'],
        'explicit_null': none,
        'zero': 0,
        'empty_list': [],
        'nested': {'usage': ['r1']}
    }
) }}
{#- get_package_config: options set under `meta` (the form that works on dbt v1 and v2). -#}
{% if execute %}
{{ assert_equal('meta: string option is read', dbt_cortex_agent.get_package_config('comment'), 'from meta') }}
{{ assert_equal('meta: false is returned, not replaced by a true default', dbt_cortex_agent.get_package_config('enable_versioning', default=true), false) }}
{{ assert_equal('meta: list option is read', dbt_cortex_agent.get_package_config('agent_grants', default=[]), ['a', 'b']) }}
{{ assert_equal('meta: map option is read', dbt_cortex_agent.get_package_config('nested'), {'usage': ['r1']}) }}
{{ assert_equal('meta: zero is returned, not replaced by the default', dbt_cortex_agent.get_package_config('zero', default=99), 0) }}
{{ assert_equal('meta: empty list is returned, not replaced by the default', dbt_cortex_agent.get_package_config('empty_list', default=['x']), []) }}
{{ assert_equal('meta: explicit null falls back to the default', dbt_cortex_agent.get_package_config('explicit_null', default='dflt'), 'dflt') }}
{{ assert_equal('absent option returns the default', dbt_cortex_agent.get_package_config('not_set_anywhere', default='dflt'), 'dflt') }}
{{ assert_true('absent option with no default returns none', dbt_cortex_agent.get_package_config('not_set_anywhere') is none) }}
{{ assert_equal('top-level key is used when meta does not have it', dbt_cortex_agent.get_package_config('alias'), 'config_alias') }}
{% endif %}
select 1 as ok
