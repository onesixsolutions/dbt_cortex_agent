{{ config(materialized='view') }}
{#- DDL generated for Cortex Agents: create, versioning, drop, and the feedback objects. -#}
{% if execute %}
{%- set rel = test_relation() -%}
{%- set profile = '{"display_name": "Bot", "color": "blue"}' -%}

-- CREATE OR REPLACE AGENT
{{ assert_sql('create: copy grants, comment and profile',
    dbt_cortex_agent.snowflake__create_cortex_agent(rel, 'models:\n  orchestration: auto', 'my comment', profile, true),
    "create or replace agent DB.SCH.OBJ copy grants comment = 'my comment' profile = '" ~ profile ~ "' from specification $$ models: orchestration: auto $$") }}
{{ assert_sql('create: copy_grants defaults to on',
    dbt_cortex_agent.snowflake__create_cortex_agent(rel, 'a: 1', none, none),
    'create or replace agent DB.SCH.OBJ copy grants from specification $$ a: 1 $$') }}
{{ assert_sql('create: copy_grants=false leaves the clause out',
    dbt_cortex_agent.snowflake__create_cortex_agent(rel, 'a: 1', none, none, false),
    'create or replace agent DB.SCH.OBJ from specification $$ a: 1 $$') }}
{{ assert_sql('create: comment without profile',
    dbt_cortex_agent.snowflake__create_cortex_agent(rel, 'a: 1', 'c', none, false),
    "create or replace agent DB.SCH.OBJ comment = 'c' from specification $$ a: 1 $$") }}
{{ assert_sql('create: profile without comment',
    dbt_cortex_agent.snowflake__create_cortex_agent(rel, 'a: 1', none, 'p', false),
    "create or replace agent DB.SCH.OBJ profile = 'p' from specification $$ a: 1 $$") }}
{{ assert_contains('create: the spec is trimmed and starts on its own line at column 0',
    dbt_cortex_agent.snowflake__create_cortex_agent(rel, '\n\n  \nmodels:\n  orchestration: auto\n\n', none, none, false),
    '$$\nmodels:\n  orchestration: auto\n  $$') }}

-- versioned path
{{ assert_sql('versioned: create if not exists never uses copy grants or replace',
    dbt_cortex_agent.snowflake__create_cortex_agent_if_not_exists(rel, 'a: 1', 'c', 'p'),
    "create agent if not exists DB.SCH.OBJ comment = 'c' profile = 'p' from specification $$ a: 1 $$") }}
{{ assert_sql('versioned: create if not exists with no options',
    dbt_cortex_agent.snowflake__create_cortex_agent_if_not_exists(rel, 'a: 1', none, none),
    'create agent if not exists DB.SCH.OBJ from specification $$ a: 1 $$') }}
{{ assert_sql('versioned: restore live from last',
    dbt_cortex_agent.snowflake__add_cortex_agent_live_version(rel),
    'alter agent DB.SCH.OBJ add live version from last') }}
{{ assert_sql('versioned: update live spec',
    dbt_cortex_agent.snowflake__alter_cortex_agent_live_spec(rel, '  a: 1  '),
    'alter agent DB.SCH.OBJ modify live version set specification = $$ a: 1 $$') }}
{{ assert_sql('versioned: commit without a comment',
    dbt_cortex_agent.snowflake__commit_cortex_agent_version(rel, none),
    'alter agent DB.SCH.OBJ commit') }}
{{ assert_sql('versioned: commit with a comment',
    dbt_cortex_agent.snowflake__commit_cortex_agent_version(rel, 'release 3'),
    "alter agent DB.SCH.OBJ commit comment = 'release 3'") }}
{{ assert_sql('versioned: default version is set with the quoted LAST form',
    dbt_cortex_agent.snowflake__set_cortex_agent_default_version(rel),
    "alter agent DB.SCH.OBJ set default_version = 'LAST'") }}

-- drop
{{ assert_sql('drop agent', dbt_cortex_agent.snowflake__get_drop_cortex_agent_sql(rel), 'drop agent if exists DB.SCH.OBJ') }}

-- feedback objects
{%- set proc = dbt_cortex_agent.snowflake__create_feedback_procedure('FDB', 'FSCH', 'FDB.FSCH.AGENT_FEEDBACK', 'owner') -%}
{{ assert_contains('feedback procedure: created in the feedback schema', normalize_sql(proc), 'create or replace procedure FDB.FSCH.AGENT_SUBMIT_FEEDBACK(') }}
{{ assert_contains('feedback procedure: replaced with copy grants, before RETURNS', normalize_sql(proc), ') copy grants returns varchar language sql execute as owner as $$') }}
{{ assert_contains('feedback procedure: inserts into the configured table', normalize_sql(proc), 'insert into FDB.FSCH.AGENT_FEEDBACK (agent_name, user_name, rating, comment, conversation_history, created_at)') }}
{{ assert_contains('feedback procedure: execute_as defaults to caller',
    normalize_sql(dbt_cortex_agent.snowflake__create_feedback_procedure('FDB', 'FSCH', 'FDB.FSCH.AGENT_FEEDBACK')),
    'execute as caller') }}
{%- set tbl = normalize_sql(dbt_cortex_agent.snowflake__create_feedback_table('FDB.FSCH.AGENT_FEEDBACK')) -%}
{{ assert_contains('feedback table: never replaced', tbl, 'create table if not exists FDB.FSCH.AGENT_FEEDBACK (') }}
{{ assert_contains('feedback table: has the conversation history column', tbl, 'conversation_history variant') }}
{% endif %}
select 1 as ok
