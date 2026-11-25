-- Custom dbt materialization for Snowflake MCP Servers.
-- The model body must be a valid Snowflake MCP server YAML specification
-- (a `tools:` array). The materialization wraps it in
-- CREATE OR REPLACE MCP SERVER ... FROM SPECIFICATION $$ ... $$.
--
-- Unlike Cortex Agents, MCP servers expose no COMMENT or PROFILE clause in their
-- DDL, so the spec body carries everything except access grants.
--
-- Config options:
--   mcp_server_grants (list or map, optional) : who gets access to the MCP server. A list of
--                                        role names grants USAGE to each; a map of privilege ->
--                                        roles grants any MCP server privilege (usage, modify).
--                                        Prefix a name with 'database role ' to grant to a
--                                        database role.
--
-- Grants: Snowflake has no ALTER MCP SERVER, so every run is a CREATE OR REPLACE, and
-- replacing a server DROPS EVERY GRANT on it (there is no COPY GRANTS clause for MCP
-- servers). Any USAGE granted by hand is therefore gone after the next `dbt run`. List the
-- roles in `mcp_server_grants` and the materialization re-issues the grants straight after
-- each replace.

{% materialization mcp_server, adapter='snowflake' %}

  {%- set mcp_server_grants = dbt_cortex_agent.get_package_config('mcp_server_grants', default=[]) -%}

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

  {%- do dbt_cortex_agent.warn_if_native_grants('mcp_server_grants') -%}

  {{ run_hooks(pre_hooks) }}

  {% call statement('main') %}
    {{ dbt_cortex_agent.snowflake__create_mcp_server(target_relation, sql) }}
  {% endcall %}

  {{ run_hooks(post_hooks) }}

  {%- for _grant_sql in dbt_cortex_agent.snowflake__grant_mcp_server_usage(target_relation, mcp_server_grants) %}
  {% call statement('grant_' ~ loop.index) %}
    {{ _grant_sql }}
  {% endcall %}
  {%- endfor %}

  {{ return({'relations': [target_relation]}) }}

{% endmaterialization %}
