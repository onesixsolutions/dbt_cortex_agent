{{
    config(
        materialized='cortex_agent',
        alias='cortex_agent_test',
        comment='Full integration test agent — exercises every config and spec option',
        profile='{"display_name": "Full Test Agent", "avatar": "robot", "color": "blue"}',
        tags=['integration'],
        agent_grants=['dbt_demo_role'],
        create_feedback_table=true
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
      name: AGENT_SUBMIT_FEEDBACK
      description: 'Records user feedback about agent responses. Call when the user says "feedback" or explicitly rates or comments on a response. Always include the last 10 conversation messages. Example: user says "1. Output wrong, expected $100" → call with rating=1, user_comment="Output wrong, expected $100". Example: user says "5. Completely Correct" → call with rating=5, user_comment="Completely Correct".'
      input_schema:
        type: object
        properties:
          agent_name:
            type: string
            description: 'Name of this agent. Always pass "{{ this.identifier | upper }}".'
          rating:
            type: number
            description: 'The user rating from 1 (worst) to 5 (best).'
          user_comment:
            type: string
            description: 'Optional free-text feedback from the user.'
          conversation_history:
            type: string
            description: 'Last 10 messages from the conversation as a JSON string, e.g. [{"role":"user","content":"..."}].'
        required:
          - agent_name
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
  AGENT_SUBMIT_FEEDBACK:
    execution_environment:
      query_timeout: 300
      type: warehouse
      warehouse: ''
    identifier: '{{ this.database }}.{{ this.schema }}.AGENT_SUBMIT_FEEDBACK'
    name: 'AGENT_SUBMIT_FEEDBACK(VARCHAR, NUMBER, VARCHAR, VARCHAR)'
    type: procedure
