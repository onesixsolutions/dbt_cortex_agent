{{
    config(
        materialized='cortex_agent',
        alias='cortex_agent_full',
        comment='Full integration test agent — exercises every config and spec option',
        profile='{"display_name": "Full Test Agent", "avatar": "robot", "color": "blue"}',
        tags=['integration', 'full']
    )
}}

models:
  orchestration: claude-4-sonnet

orchestration:
  budget:
    seconds: 60
    tokens: 32000

instructions:
  response: 'You are a comprehensive integration test assistant. Answer clearly and concisely.'
  orchestration: 'Use the analyst tool for structured data questions and the search tool for unstructured content.'
  sample_questions:
    - question: 'What was total revenue last quarter?'
    - question: 'Show me the top 10 clients by revenue.'
    - question: 'What are the most common chargeback reasons?'

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

  - tool_spec:
      type: cortex_search
      name: search_tool
      description: 'Searches unstructured content for relevant information.'
      input_schema:
        type: object
        properties:
          query:
            type: string
            description: 'A natural language search query.'
        required:
          - query

tool_resources:
  analyst_tool:
    semantic_view: '{{ ref("test_semantic_view") }}'
  search_tool:
    name: '{{ var("test_cortex_search_service", "DB.SCHEMA.SEARCH_SERVICE") }}'
    max_results: 10
    title_column: title
    id_column: id
