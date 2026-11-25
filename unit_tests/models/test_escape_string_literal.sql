{{ config(materialized='view', grants={'select': ['some_role']}) }}
{#- escape_string_literal, and its use wherever a config value is placed inside a SQL string. -#}
{% if execute %}
{%- set rel = test_relation() -%}
{{ assert_equal('escape: a plain value is unchanged', dbt_cortex_agent.escape_string_literal('plain comment'), 'plain comment') }}
{{ assert_equal('escape: an apostrophe is doubled', dbt_cortex_agent.escape_string_literal("Don't use"), "Don''t use") }}
{{ assert_equal('escape: every apostrophe is doubled', dbt_cortex_agent.escape_string_literal("a'b'c"), "a''b''c") }}
{{ assert_equal('escape: a value already escaped by doubling is left alone', dbt_cortex_agent.escape_string_literal("Don''t use"), "Don''t use") }}
{{ assert_equal('escape: a value already escaped with a backslash is left alone', dbt_cortex_agent.escape_string_literal("Don\\'t use"), "Don\\'t use") }}
{{ assert_equal('escape: double quotes are untouched (JSON profiles)', dbt_cortex_agent.escape_string_literal('{"a": "b"}'), '{"a": "b"}') }}
{{ assert_equal('escape: non-string values are stringified', dbt_cortex_agent.escape_string_literal(1800), '1800') }}
{{ assert_equal('escape: empty string stays empty', dbt_cortex_agent.escape_string_literal(''), '') }}

{{ assert_sql('agent create: apostrophes in comment and profile are escaped',
    dbt_cortex_agent.snowflake__create_cortex_agent(rel, 'a: 1', "It's mine", '{"display_name": "Bob\'s Agent"}', false),
    "create or replace agent DB.SCH.OBJ comment = 'It''s mine' profile = '{\"display_name\": \"Bob''s Agent\"}' from specification $$ a: 1 $$") }}
{{ assert_sql('agent create if not exists: apostrophes in comment and profile are escaped',
    dbt_cortex_agent.snowflake__create_cortex_agent_if_not_exists(rel, 'a: 1', "It's mine", '{"display_name": "Bob\'s Agent"}'),
    "create agent if not exists DB.SCH.OBJ comment = 'It''s mine' profile = '{\"display_name\": \"Bob''s Agent\"}' from specification $$ a: 1 $$") }}
{{ assert_sql('agent commit: apostrophe in the version comment is escaped',
    dbt_cortex_agent.snowflake__commit_cortex_agent_version(rel, "CI's commit"),
    "alter agent DB.SCH.OBJ commit comment = 'CI''s commit'") }}
{{ assert_contains('search service create: apostrophe in the comment is escaped',
    normalize_sql(dbt_cortex_agent.snowflake__create_cortex_search_service(rel, 'select 1', 'body', ['id'], 'WH', '1 hour', none, none, none, none, none, none, none, "it's indexed")),
    "comment = 'it''s indexed' as ( select 1 )") }}
{{ assert_contains('search service alter: apostrophe in the comment is escaped',
    dbt_cortex_agent.snowflake__alter_cortex_search_service(rel, ['a'], 'WH', '1 hour', none, none, none, none, "it's indexed") | join(' | '),
    "set comment = 'it''s indexed'") }}

{#- This model sets dbt's native `grants` config (see the config block above); the package
    macro must notice it. warn_if_native_grants only warns, so here we check the condition it
    keys on rather than the log output. -#}
{{ assert_true('native grants config is visible to the package through config.get', config.get('grants', default=none)) }}
{% endif %}
select 1 as ok
