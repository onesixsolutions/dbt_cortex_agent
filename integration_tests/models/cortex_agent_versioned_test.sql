{{
    config(
        materialized='cortex_agent',
        alias='cortex_agent_versioned_test',
        comment='Versioned integration test agent — exercises enable_versioning, auto_commit, and version_comment',
        tags=['integration'],
        version_comment='CI test commit'
    )
}}

models:
  orchestration: auto

orchestration:
  budget:
    seconds: 30
    tokens: 8000

instructions:
  response: 'You are a versioning integration test assistant.'
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
