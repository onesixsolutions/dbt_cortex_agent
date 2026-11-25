{#
  Versioned agent whose specification never changes between runs.

  With commit_only_on_change (the default) the materialization compares the compiled
  specification with the deployed one and, finding them equal, must not modify LIVE or commit.
  So however many times the suite runs, this agent must never gain a version beyond the one it
  was created with. cortex_agent_unchanged_test_versions captures SHOW VERSIONS for the test.

  If Snowflake ever returned the stored specification in a form that no longer compares equal
  to the model body, every run would commit a version and the test would fail — which is the
  signal that change detection has stopped working.
#}
{{
    config(
        materialized='cortex_agent',
        alias='cortex_agent_unchanged_test',
        tags=['integration', 'versioning'],
        meta={'comment': 'Agent with a constant specification, for change-detection tests'}
    )
}}

models:
  orchestration: auto

orchestration:
  budget:
    seconds: 30
    tokens: 8000

instructions:
  response: 'You are an unchanged-specification integration test assistant.'
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
