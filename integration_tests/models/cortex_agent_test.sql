{{
    config(
        materialized='cortex_agent',
        alias='cortex_agent_test',
        comment='Full integration test agent — exercises every config and spec option',
        profile='{"display_name": "Full Test Agent", "avatar": "robot", "color": "blue"}',
        tags=['integration'],
        agent_grants=['dbt_demo_role'],
        feedback_table=target.database ~ '.' ~ target.schema ~ '_INTEGRATION_TESTS.CORTEX_AGENT_FEEDBACK'
    )
}}

models:
  orchestration: auto

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

  - tool_spec:
      type: generic
      name: SUBMIT_FEEDBACK
      description: 'Records user feedback about agent responses. Call when the user expresses satisfaction or dissatisfaction, or explicitly asks to rate or submit feedback. Always include the last 10 conversation messages.'
      input_schema:
        type: object
        properties:
          session_id:
            type: string
            description: 'Current conversation session identifier.'
          rating:
            type: string
            enum: [good, bad]
            description: 'The user rating.'
          comment:
            type: string
            description: 'Optional free-text feedback from the user.'
          conversation_history:
            type: string
            description: 'Last 10 messages from the conversation as a JSON string, e.g. [{"role":"user","content":"..."}].'
        required:
          - session_id
          - rating
          - conversation_history

skills: []

tool_resources:
  analyst_tool:
    semantic_view: '{{ ref('test_semantic_view') }}'
  search_tool:
    name: '{{ var("test_cortex_search_service") }}'
    max_results: 10
    title_column: description
    id_column: id
  SUBMIT_FEEDBACK:
    execution_environment:
      query_timeout: 300
      type: warehouse
      warehouse: ''
    identifier: '{{ this.database }}.{{ this.schema }}.{{ this.identifier | upper }}_SUBMIT_FEEDBACK'
    name: '{{ this.identifier | upper }}_SUBMIT_FEEDBACK(VARCHAR, VARCHAR, VARCHAR, VARCHAR)'
    type: procedure
