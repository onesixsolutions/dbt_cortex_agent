{{
    config(
        materialized='mcp_server',
        alias='mcp_server_test',
        tags=['integration']
    )
}}

tools:
  - name: "product_search"
    type: "CORTEX_SEARCH_SERVICE_QUERY"
    identifier: "{{ var('test_cortex_search_service') }}"
    title: "Product Search"
    description: "Cortex Search service over unstructured content."

  - name: "revenue_analyst"
    type: "CORTEX_ANALYST_MESSAGE"
    identifier: "{{ ref('test_semantic_view') }}"
    title: "Revenue Analyst"
    description: "Semantic view for structured revenue analysis."

  - name: "sql_exec_tool"
    type: "SYSTEM_EXECUTE_SQL"
    title: "SQL Execution"
    description: "Execute read-only SQL against Snowflake."
    config:
      read_only: true
      query_timeout: 120
      warehouse: "{{ target.warehouse }}"
