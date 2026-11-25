{#
  Exercises revoke_unlisted_grants end to end.

  The materialization runs post-hooks BEFORE its revoke and grant steps, so the post-hook below
  plants a MONITOR grant that agent_grants does not list. With revoke_unlisted_grants=true the
  materialization must then find it via SHOW GRANTS ON AGENT and revoke it, while leaving the
  listed USAGE grant in place. cortex_agent_revoke_test_grants captures the end state.

  enable_versioning=false keeps this agent on the CREATE OR REPLACE path, so each run starts
  from the grants that COPY GRANTS carried over plus the planted one.
#}
{{
    config(
        materialized='cortex_agent',
        alias='cortex_agent_revoke_test',
        tags=['integration', 'grants'],
        post_hook="grant monitor on agent {{ this }} to role dbt_demo_role",
        meta={
            'enable_versioning': false,
            'agent_grants': ['dbt_demo_role'],
            'revoke_unlisted_grants': true
        }
    )
}}

models:
  orchestration: auto

orchestration:
  budget:
    seconds: 30
    tokens: 8000

instructions:
  response: 'You are a grant-revocation integration test assistant.'
  orchestration: 'Use the analyst tool for structured data questions.'

tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: analyst_tool
      description: 'Answers structured data questions using a semantic view.'
      input_schema:
        type: object
        properties:
          question:
            type: string
            description: 'A natural language question about the data.'
        required:
          - question

tool_resources:
  analyst_tool:
    semantic_view: '{{ ref('test_semantic_view') }}'
    execution_environment:
      type: warehouse
      warehouse: DBT_WH
      query_timeout: 60
