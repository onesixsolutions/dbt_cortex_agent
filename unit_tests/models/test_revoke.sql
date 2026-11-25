{{ config(materialized='view') }}
{#- get_revoke_statements_for_rows: the comparison half of revoke_unlisted_grants, fed with rows
    shaped like SHOW GRANTS ON <object> output. -#}
{% if execute %}
{%- set current = [
  {'privilege': 'OWNERSHIP', 'granted_to': 'ROLE',          'grantee_name': 'OWNER_ROLE'},
  {'privilege': 'USAGE',     'granted_to': 'ROLE',          'grantee_name': 'R1'},
  {'privilege': 'USAGE',     'granted_to': 'ROLE',          'grantee_name': 'Mixed Case'},
  {'privilege': 'USAGE',     'granted_to': 'ROLE',          'grantee_name': 'STALE_ROLE'},
  {'privilege': 'MONITOR',   'granted_to': 'ROLE',          'grantee_name': 'OPS'},
  {'privilege': 'MONITOR',   'granted_to': 'ROLE',          'grantee_name': 'R1'},
  {'privilege': 'USAGE',     'granted_to': 'DATABASE_ROLE', 'grantee_name': 'SOME_DB_ROLE'},
  {'privilege': 'USAGE',     'granted_to': 'SHARE',         'grantee_name': 'SOME_SHARE'},
  {'privilege': 'USAGE',     'granted_to': 'APPLICATION_ROLE', 'grantee_name': 'SOME_APP_ROLE'}
] -%}

{{ assert_equal('revoke: only unlisted account-role grants are revoked',
    dbt_cortex_agent.get_revoke_statements_for_rows('agent', 'DB.SCH.OBJ', {'usage': ['r1', '"Mixed Case"'], 'monitor': 'ops'}, current),
    ['revoke usage on agent DB.SCH.OBJ from role "STALE_ROLE"',
     'revoke monitor on agent DB.SCH.OBJ from role "R1"']) }}

{%- set all_revoked = dbt_cortex_agent.get_revoke_statements_for_rows('agent', 'DB.SCH.OBJ', [], current) -%}
{{ assert_equal('revoke: an empty grants option revokes every account-role grant',
    all_revoked,
    ['revoke usage on agent DB.SCH.OBJ from role "R1"',
     'revoke usage on agent DB.SCH.OBJ from role "Mixed Case"',
     'revoke usage on agent DB.SCH.OBJ from role "STALE_ROLE"',
     'revoke monitor on agent DB.SCH.OBJ from role "OPS"',
     'revoke monitor on agent DB.SCH.OBJ from role "R1"']) }}
{{ assert_not_contains('revoke: OWNERSHIP is never revoked', all_revoked | join(' ; '), 'OWNER_ROLE') }}
{{ assert_not_contains('revoke: database role grants are never revoked', all_revoked | join(' ; '), 'SOME_DB_ROLE') }}
{{ assert_not_contains('revoke: share grants are never revoked', all_revoked | join(' ; '), 'SOME_SHARE') }}
{{ assert_not_contains('revoke: application role grants are never revoked', all_revoked | join(' ; '), 'SOME_APP_ROLE') }}

{{ assert_equal('revoke: a listed role is matched case-insensitively',
    dbt_cortex_agent.get_revoke_statements_for_rows('agent', 'DB.SCH.OBJ', ['R1', 'stale_role', '"Mixed Case"'], [current[1], current[2], current[3]]),
    []) }}
{{ assert_equal('revoke: an explicit "role " prefix is matched too',
    dbt_cortex_agent.get_revoke_statements_for_rows('agent', 'DB.SCH.OBJ', ['role r1'], [current[1]]),
    []) }}
{{ assert_equal('revoke: a quoted name must match exactly, case included',
    dbt_cortex_agent.get_revoke_statements_for_rows('agent', 'DB.SCH.OBJ', ['"mixed case"'], [current[2]]),
    ['revoke usage on agent DB.SCH.OBJ from role "Mixed Case"']) }}
{{ assert_equal('revoke: a role listed for one privilege keeps only that privilege',
    dbt_cortex_agent.get_revoke_statements_for_rows('agent', 'DB.SCH.OBJ', {'usage': ['r1']}, [current[1], current[5]]),
    ['revoke monitor on agent DB.SCH.OBJ from role "R1"']) }}
{{ assert_equal('revoke: listing a database role does not protect an account role of the same name',
    dbt_cortex_agent.get_revoke_statements_for_rows('agent', 'DB.SCH.OBJ', ['database role R1'], [current[1]]),
    ['revoke usage on agent DB.SCH.OBJ from role "R1"']) }}
{{ assert_equal('revoke: nothing to do when there are no current grants',
    dbt_cortex_agent.get_revoke_statements_for_rows('agent', 'DB.SCH.OBJ', ['r1'], []),
    []) }}
{{ assert_equal('revoke: the object type is carried into the statement',
    dbt_cortex_agent.get_revoke_statements_for_rows('cortex search service', 'DB.SCH.SVC', [], [current[3]]),
    ['revoke usage on cortex search service DB.SCH.SVC from role "STALE_ROLE"']) }}
{{ assert_equal('revoke: privilege and granted_to are compared case-insensitively',
    dbt_cortex_agent.get_revoke_statements_for_rows('agent', 'DB.SCH.OBJ', ['r1'], [{'privilege': 'usage', 'granted_to': 'role', 'grantee_name': 'R1'}, {'privilege': 'ownership', 'granted_to': 'role', 'grantee_name': 'O'}]),
    []) }}
{% endif %}
select 1 as ok
