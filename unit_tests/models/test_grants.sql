{{ config(materialized='view') }}
{#- Grant statement generation: macros/utils/grants.sql and the per-object grant macros. -#}
{% if execute %}
{%- set rel = test_relation() -%}

-- normalize_grants
{{ assert_equal('normalize: list becomes usage', dbt_cortex_agent.normalize_grants(['r1', 'r2']), {'usage': ['r1', 'r2']}) }}
{{ assert_equal('normalize: bare string becomes a one-role usage list', dbt_cortex_agent.normalize_grants('solo'), {'usage': ['solo']}) }}
{{ assert_equal('normalize: none becomes empty', dbt_cortex_agent.normalize_grants(none), {}) }}
{{ assert_equal('normalize: empty list becomes usage with no grantees', dbt_cortex_agent.normalize_grants([]), {'usage': []}) }}
{{ assert_equal('normalize: empty map stays empty', dbt_cortex_agent.normalize_grants({}), {}) }}
{{ assert_equal('normalize: map is kept', dbt_cortex_agent.normalize_grants({'usage': ['r1'], 'monitor': ['r2']}), {'usage': ['r1'], 'monitor': ['r2']}) }}
{{ assert_equal('normalize: privilege names are lower-cased and trimmed', dbt_cortex_agent.normalize_grants({' MONITOR ': ['r1']}), {'monitor': ['r1']}) }}
{{ assert_equal('normalize: scalar grantee becomes a list', dbt_cortex_agent.normalize_grants({'usage': 'r1'}), {'usage': ['r1']}) }}
{{ assert_equal('normalize: null grantees become an empty list', dbt_cortex_agent.normalize_grants({'usage': none}), {'usage': []}) }}

-- grantee_clause
{{ assert_equal('grantee: plain name is an account role', dbt_cortex_agent.grantee_clause('analyst'), 'role analyst') }}
{{ assert_equal('grantee: surrounding whitespace is trimmed', dbt_cortex_agent.grantee_clause('  analyst  '), 'role analyst') }}
{{ assert_equal('grantee: database role prefix is kept', dbt_cortex_agent.grantee_clause('database role MY_DB.READER'), 'database role MY_DB.READER') }}
{{ assert_equal('grantee: database role prefix is case-insensitive', dbt_cortex_agent.grantee_clause('DATABASE ROLE MY_DB.READER'), 'DATABASE ROLE MY_DB.READER') }}
{{ assert_equal('grantee: explicit role prefix is not doubled', dbt_cortex_agent.grantee_clause('role analyst'), 'role analyst') }}
{{ assert_equal('grantee: quoted name is kept as written', dbt_cortex_agent.grantee_clause('"Mixed Case"'), 'role "Mixed Case"') }}
{{ assert_equal('grantee: a name that merely starts with "role" is still a role name', dbt_cortex_agent.grantee_clause('role_admin'), 'role role_admin') }}

-- get_grant_statements
{{ assert_equal('statements: one per privilege/grantee pair',
    dbt_cortex_agent.get_grant_statements('agent', 'DB.SCH.OBJ', {'usage': ['r1', 'database role D.R'], 'monitor': 'ops'}),
    ['grant usage on agent DB.SCH.OBJ to role r1',
     'grant usage on agent DB.SCH.OBJ to database role D.R',
     'grant monitor on agent DB.SCH.OBJ to role ops']) }}
{{ assert_equal('statements: nothing for an empty list', dbt_cortex_agent.get_grant_statements('agent', 'DB.SCH.OBJ', []), []) }}
{{ assert_equal('statements: nothing for none', dbt_cortex_agent.get_grant_statements('agent', 'DB.SCH.OBJ', none), []) }}
{{ assert_equal('statements: nothing for a privilege with no grantees', dbt_cortex_agent.get_grant_statements('agent', 'DB.SCH.OBJ', {'usage': []}), []) }}

-- per-object macros
{{ assert_equal('agent: list form grants usage',
    dbt_cortex_agent.snowflake__grant_cortex_agent_usage(rel, ['r1', 'r2']),
    ['grant usage on agent DB.SCH.OBJ to role r1', 'grant usage on agent DB.SCH.OBJ to role r2']) }}
{{ assert_equal('agent: map form grants each privilege',
    dbt_cortex_agent.snowflake__grant_cortex_agent_usage(rel, {'usage': ['r1'], 'monitor': ['r2'], 'modify': ['r3']}),
    ['grant usage on agent DB.SCH.OBJ to role r1', 'grant monitor on agent DB.SCH.OBJ to role r2', 'grant modify on agent DB.SCH.OBJ to role r3']) }}
{{ assert_equal('agent: default empty list produces no statements', dbt_cortex_agent.snowflake__grant_cortex_agent_usage(rel, []), []) }}
{{ assert_equal('search service: list form',
    dbt_cortex_agent.snowflake__grant_cortex_search_service_usage(rel, ['r1']),
    ['grant usage on cortex search service DB.SCH.OBJ to role r1']) }}
{{ assert_equal('search service: map form',
    dbt_cortex_agent.snowflake__grant_cortex_search_service_usage(rel, {'usage': ['r1'], 'operate': ['r2'], 'monitor': ['r3']}),
    ['grant usage on cortex search service DB.SCH.OBJ to role r1', 'grant operate on cortex search service DB.SCH.OBJ to role r2', 'grant monitor on cortex search service DB.SCH.OBJ to role r3']) }}
{{ assert_equal('mcp server: list form',
    dbt_cortex_agent.snowflake__grant_mcp_server_usage(rel, ['r1']),
    ['grant usage on mcp server DB.SCH.OBJ to role r1']) }}
{{ assert_equal('mcp server: map form with a database role',
    dbt_cortex_agent.snowflake__grant_mcp_server_usage(rel, {'usage': ['database role D.R'], 'modify': ['r2']}),
    ['grant usage on mcp server DB.SCH.OBJ to database role D.R', 'grant modify on mcp server DB.SCH.OBJ to role r2']) }}
{{ assert_equal('mcp server: default empty list produces no statements', dbt_cortex_agent.snowflake__grant_mcp_server_usage(rel, []), []) }}

-- feedback procedure
{{ assert_equal('feedback procedure: usage with the full argument signature',
    dbt_cortex_agent.snowflake__grant_feedback_procedure_usage('FDB', 'FSCH', ['r1', 'database role D.R']),
    ['grant usage on procedure FDB.FSCH.AGENT_SUBMIT_FEEDBACK(varchar, number, varchar, varchar) to role r1',
     'grant usage on procedure FDB.FSCH.AGENT_SUBMIT_FEEDBACK(varchar, number, varchar, varchar) to database role D.R']) }}
{{ assert_equal('feedback procedure: only USAGE grantees of the agent are granted (as the materialization does)',
    dbt_cortex_agent.snowflake__grant_feedback_procedure_usage('FDB', 'FSCH', dbt_cortex_agent.normalize_grants({'usage': ['r1'], 'monitor': ['r9']}).get('usage', [])),
    ['grant usage on procedure FDB.FSCH.AGENT_SUBMIT_FEEDBACK(varchar, number, varchar, varchar) to role r1']) }}
{{ assert_equal('feedback procedure: nothing when the agent grants no USAGE',
    dbt_cortex_agent.snowflake__grant_feedback_procedure_usage('FDB', 'FSCH', dbt_cortex_agent.normalize_grants({'monitor': ['r9']}).get('usage', [])),
    []) }}
{% endif %}
select 1 as ok
