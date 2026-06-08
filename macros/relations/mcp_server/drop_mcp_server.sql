-- Generates DROP MCP SERVER IF EXISTS DDL for a Snowflake MCP Server.
-- Use this in a dbt operation or post-hook when you need to explicitly remove an MCP server:
--
--   {% do run_query(dbt_cortex_agent.snowflake__get_drop_mcp_server_sql(this)) %}
{% macro snowflake__get_drop_mcp_server_sql(relation) %}

  drop mcp server if exists
    {{ relation.database }}.{{ relation.schema }}.{{ relation.identifier }}

{% endmacro %}
