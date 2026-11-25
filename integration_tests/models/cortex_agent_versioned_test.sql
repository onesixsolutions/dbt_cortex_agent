{#
  Versioned agent whose specification, comment and profile all change when the suite is run a
  second time (--vars '{second_run: true}'). That lets the tests prove that:
    - a changed specification commits a new version (cortex_agent_versioned_test_increments)
    - COMMENT and PROFILE are re-applied to an agent that already exists
      (cortex_agent_versioned_test_properties_applied)
  CI then runs this model a third time with --full-refresh and the same vars, which must NOT
  replace the agent or add a version.
#}
{{
    config(
        materialized='cortex_agent',
        alias='cortex_agent_versioned_test',
        tags=['integration'],
        meta={
            'comment': "Versioned integration test agent — exercises enable_versioning, auto_commit, and version_comment. It's also the apostrophe test." ~ (' [second run]' if var('second_run', false) else ''),
            'profile': '{"display_name": "Versioned Test Agent' ~ (' second run' if var('second_run', false) else '') ~ '", "color": "green"}',
            'version_comment': "CI's test commit"
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
  response: 'You are a versioning integration test assistant.{{ " This is the second run." if var("second_run", false) else "" }}'
  orchestration: 'Use the analyst tool for structured data questions.'
  sample_questions:
    - question: 'What was total revenue last quarter?'

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
