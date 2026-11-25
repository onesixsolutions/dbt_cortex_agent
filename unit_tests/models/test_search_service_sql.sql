{{ config(materialized='view') }}
{#- DDL generated for Cortex Search Services: create, alter, drop, and immutable-property drift. -#}
{% if execute %}
{%- set rel = test_relation() -%}

-- CREATE
{{ assert_sql('create: required options only',
    dbt_cortex_agent.snowflake__create_cortex_search_service(rel, 'select 1', 'body', ['id'], 'WH', '1 hour', none, none, none, none, none, none, none, none),
    "create or replace cortex search service DB.SCH.OBJ on body attributes id warehouse = WH target_lag = '1 hour' as ( select 1 )") }}
{{ assert_sql('create: every option, in the documented clause order',
    dbt_cortex_agent.snowflake__create_cortex_search_service(rel, 'select 1', 'body', ['id', 'title'], 'WH', '7 days', ['id', 'region'], 'snowflake-arctic-embed-m-v1.5', 'FULL', 'ON_SCHEDULE', 7, true, 1800, 'my comment'),
    "create or replace cortex search service DB.SCH.OBJ on body primary key (id, region) attributes id, title warehouse = WH target_lag = '7 days' embedding_model = 'snowflake-arctic-embed-m-v1.5' refresh_mode = FULL initialize = ON_SCHEDULE full_index_build_interval_days = 7 request_logging = true auto_suspend = 1800 comment = 'my comment' as ( select 1 )") }}
{{ assert_sql('create: request_logging false is emitted, not dropped',
    dbt_cortex_agent.snowflake__create_cortex_search_service(rel, 'select 1', 'body', ['id'], 'WH', '1 hour', none, none, none, none, none, false, none, none),
    "create or replace cortex search service DB.SCH.OBJ on body attributes id warehouse = WH target_lag = '1 hour' request_logging = false as ( select 1 )") }}
{{ assert_sql('create: an empty primary key list emits no PRIMARY KEY clause',
    dbt_cortex_agent.snowflake__create_cortex_search_service(rel, 'select 1', 'body', ['id'], 'WH', '1 hour', [], none, none, none, none, none, none, none),
    "create or replace cortex search service DB.SCH.OBJ on body attributes id warehouse = WH target_lag = '1 hour' as ( select 1 )") }}

-- ALTER
{{ assert_equal('alter: one statement per property, attributes last',
    dbt_cortex_agent.snowflake__alter_cortex_search_service(rel, ['a', 'b'], 'WH', '1 hour', ['id'], 3, true, 1800, 'hello'),
    ["alter cortex search service if exists DB.SCH.OBJ set target_lag = '1 hour'",
     'alter cortex search service if exists DB.SCH.OBJ set warehouse = WH',
     'alter cortex search service if exists DB.SCH.OBJ set full_index_build_interval_days = 3',
     'alter cortex search service if exists DB.SCH.OBJ set request_logging = true',
     'alter cortex search service if exists DB.SCH.OBJ set auto_suspend = 1800',
     "alter cortex search service if exists DB.SCH.OBJ set comment = 'hello'",
     'alter cortex search service if exists DB.SCH.OBJ set primary key = (id)',
     'alter cortex search service if exists DB.SCH.OBJ set attributes (a, b)']) }}
{{ assert_equal('alter: only the always-present properties',
    dbt_cortex_agent.snowflake__alter_cortex_search_service(rel, ['a'], 'WH', '7 days', none, none, none, none, none),
    ["alter cortex search service if exists DB.SCH.OBJ set target_lag = '7 days'",
     'alter cortex search service if exists DB.SCH.OBJ set warehouse = WH',
     'alter cortex search service if exists DB.SCH.OBJ set attributes (a)']) }}
{{ assert_equal('alter: request_logging false is emitted, composite primary key is joined',
    dbt_cortex_agent.snowflake__alter_cortex_search_service(rel, ['a'], 'WH', '7 days', ['id', 'region'], none, false, none, none),
    ["alter cortex search service if exists DB.SCH.OBJ set target_lag = '7 days'",
     'alter cortex search service if exists DB.SCH.OBJ set warehouse = WH',
     'alter cortex search service if exists DB.SCH.OBJ set request_logging = false',
     'alter cortex search service if exists DB.SCH.OBJ set primary key = (id, region)',
     'alter cortex search service if exists DB.SCH.OBJ set attributes (a)']) }}
{%- set alters = dbt_cortex_agent.snowflake__alter_cortex_search_service(rel, ['a'], 'WH', '7 days', none, none, none, none, none) -%}
{{ assert_true('alter: the statement list is never empty (the materialization names the last one main)', alters | length > 0) }}
{{ assert_not_contains('alter: no statement carries a trailing semicolon', alters | join(' | '), ';') }}

-- DROP
{{ assert_sql('drop search service', dbt_cortex_agent.snowflake__get_drop_cortex_search_service_sql(rel), 'drop cortex search service if exists DB.SCH.OBJ') }}

-- immutable drift
{{ assert_equal('drift: none when the search column matches, ignoring case',
    dbt_cortex_agent.get_search_service_immutable_drift(rel, 'description', none, 'DESCRIPTION', none), []) }}
{{ assert_equal('drift: none when the search column matches, ignoring quotes',
    dbt_cortex_agent.get_search_service_immutable_drift(rel, '"description"', none, 'DESCRIPTION', none), []) }}
{{ assert_equal('drift: none when the embedding model matches, ignoring case',
    dbt_cortex_agent.get_search_service_immutable_drift(rel, 'body', 'Snowflake-Arctic-Embed-M-v1.5', 'BODY', 'snowflake-arctic-embed-m-v1.5'), []) }}
{{ assert_equal('drift: an embedding model left to the default is not compared',
    dbt_cortex_agent.get_search_service_immutable_drift(rel, 'body', none, 'BODY', 'snowflake-arctic-embed-m-v1.5'), []) }}
{{ assert_equal('drift: a configured embedding model is not compared when the deployed value was not looked up',
    dbt_cortex_agent.get_search_service_immutable_drift(rel, 'body', 'some-model', 'BODY', none), []) }}
{%- set drift = dbt_cortex_agent.get_search_service_immutable_drift(rel, 'body', 'new-model', 'DESCRIPTION', 'old-model') -%}
{{ assert_equal('drift: one message per drifted property', drift | length, 2) }}
{{ assert_contains('drift: search column message names both values', drift[0], "`search_column` is configured as 'body' but the deployed service searches 'DESCRIPTION'") }}
{{ assert_contains('drift: embedding model message names both values', drift[1], "`embedding_model` is configured as 'new-model' but the deployed service uses 'old-model'") }}
{{ assert_contains('drift: message names the service', drift[0], 'DB.SCH.OBJ') }}
{{ assert_contains('drift: message points at --full-refresh', drift[0], '--full-refresh') }}
{% endif %}
select 1 as ok
