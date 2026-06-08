-- Custom dbt materialization for Snowflake MCP Servers.
-- The model body must be a valid Snowflake MCP server YAML specification
-- (a `tools:` array). The materialization wraps it in
-- CREATE OR REPLACE MCP SERVER ... FROM SPECIFICATION $$ ... $$.
--
-- Unlike Cortex Agents, MCP servers expose no COMMENT or PROFILE clause in their
-- DDL, so this materialization takes no extra config options beyond the spec body.

{% materialization mcp_server, adapter='snowflake' %}

  -- dbt has no native 'mcp server' relation type. 'view' is used as a placeholder
  -- for graph tracking only — the actual DDL is always CREATE OR REPLACE MCP SERVER.
  --
  -- IMPORTANT for consumers: if you change a model away from mcp_server
  -- materialization, dbt will attempt DROP VIEW IF EXISTS, which may silently no-op
  -- rather than dropping the MCP server. Drop it manually before switching:
  --   DROP MCP SERVER IF EXISTS <database>.<schema>.<name>;
  {%- set target_relation = api.Relation.create(
      identifier=this.identifier,
      schema=this.schema,
      database=this.database,
      type='view'
  ) -%}

  {{ run_hooks(pre_hooks) }}

  {% call statement('main') %}
    {{ dbt_cortex_agent.snowflake__create_mcp_server(target_relation, sql) }}
  {% endcall %}

  {{ run_hooks(post_hooks) }}

  {{ return({'relations': [target_relation]}) }}

{% endmaterialization %}
