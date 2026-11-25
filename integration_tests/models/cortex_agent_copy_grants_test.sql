{#
  Exercises COPY GRANTS on CREATE OR REPLACE AGENT.

  enable_versioning=false puts this agent on the CREATE OR REPLACE path on every run, and it
  sets no agent_grants, so the materialization itself grants nothing. The post-hook grants
  MONITOR by hand on a FIRST run only; on a run started with --vars '{second_run: true}' it
  grants nothing. If the MONITOR grant is still there after that second run, it can only have
  survived the replace because of COPY GRANTS.

  CI runs `dbt run` twice (the second time with second_run=true) before `dbt test`. A single
  local run still passes, since the first-run hook leaves the grant in place.
#}
{{
    config(
        materialized='cortex_agent',
        alias='cortex_agent_copy_grants_test',
        tags=['integration', 'grants'],
        post_hook="{% if not var('second_run', false) %}grant monitor on agent {{ this }} to role dbt_demo_role{% else %}select 1{% endif %}",
        meta={'enable_versioning': false}
    )
}}

models:
  orchestration: auto

orchestration:
  budget:
    seconds: 30
    tokens: 8000

instructions:
  response: 'You are a copy-grants integration test assistant.'
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
