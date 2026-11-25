{{ config(materialized='view') }}
{#- Cases that must FAIL compilation. Each is gated behind the `expect_error` var, so a normal
    run compiles this model cleanly; scripts/run_unit_tests.sh then compiles it once per case
    listed in unit_tests/expected_errors.txt and checks that dbt fails with the expected message. -#}
{% if execute %}
{%- set case = var('expect_error', '') -%}
{%- if case == 'grant_ownership' -%}
  {{ dbt_cortex_agent.normalize_grants({'ownership': ['r1']}, 'agent_grants') }}
{%- elif case == 'grant_ownership_mixed_case' -%}
  {{ dbt_cortex_agent.get_grant_statements('agent', 'DB.SCH.OBJ', {'usage': ['r1'], ' OwnerShip ': ['r2']}, 'agent_grants') }}
{%- elif case == 'assertion_helper_detects_mismatch' -%}
  {{ assert_equal('deliberate mismatch', 'a', 'b') }}
{%- elif case == 'assertion_helper_detects_sql_mismatch' -%}
  {{ assert_sql('deliberate sql mismatch', 'select 1', 'select 2') }}
{%- endif -%}
{% endif %}
select 1 as ok
