-- Custom dbt materialization for Snowflake Cortex Search Services.
-- Unlike cortex_agent/mcp_server, the model body is a NORMAL dbt SELECT query — it
-- becomes the `AS <query>` clause of the search service, not a passthrough YAML spec.
-- Supports single-index syntax only (ON + ATTRIBUTES) — TEXT/VECTOR multi-index
-- definitions are not supported.
--
-- Refresh behaviour: CREATE OR REPLACE only runs on the first dbt run for a given
-- service, or when `dbt run --full-refresh` is passed. On every subsequent normal run,
-- mutable properties (target_lag, warehouse, comment, auto_suspend, request_logging,
-- full_index_build_interval_days, attributes, primary_key) are updated in place via
-- ALTER ... SET, so the search index is never gratuitously rebuilt.
--
-- Config options:
--   search_column (string, required)   : column CORTEX SEARCH SERVICE indexes and searches over
--   attributes (list, required)        : non-empty list of filterable/returnable column names
--   target_lag (string, required)      : e.g. '1 hour', '7 days' — no Snowflake default
--   warehouse (string, optional)       : defaults to target.warehouse
--   primary_key (list, optional)       : enables optimized incremental refresh
--   embedding_model (string, optional) : immutable after create
--   refresh_mode (string, optional)    : INCREMENTAL|FULL, immutable after create
--   initialize (string, optional)      : ON_CREATE|ON_SCHEDULE, immutable after create
--   full_index_build_interval_days (int, optional)
--   request_logging (bool, optional)
--   auto_suspend (int, optional)       : seconds, minimum 1800
--   comment (string, optional)
--   search_service_grants (list, optional) : role names to grant USAGE on the service
--
-- IMPORTANT for consumers: if you change a model away from cortex_search_service
-- materialization, dbt will attempt DROP VIEW IF EXISTS, which may silently no-op
-- rather than dropping the search service. Drop it manually before switching:
--   DROP CORTEX SEARCH SERVICE IF EXISTS <database>.<schema>.<name>;

{% materialization cortex_search_service, adapter='snowflake' %}

  {%- set search_column                  = config.get('search_column', default=none) -%}
  {%- set attributes                     = config.get('attributes', default=none) -%}
  {%- set warehouse                      = config.get('warehouse', default=target.warehouse) -%}
  {%- set target_lag                     = config.get('target_lag', default=none) -%}
  {%- set primary_key                    = config.get('primary_key', default=none) -%}
  {%- set embedding_model                = config.get('embedding_model', default=none) -%}
  {%- set refresh_mode                   = config.get('refresh_mode', default=none) -%}
  {%- set initialize                     = config.get('initialize', default=none) -%}
  {%- set full_index_build_interval_days = config.get('full_index_build_interval_days', default=none) -%}
  {%- set request_logging                = config.get('request_logging', default=none) -%}
  {%- set auto_suspend                   = config.get('auto_suspend', default=none) -%}
  {%- set comment                        = config.get('comment', default=none) -%}
  {%- set search_service_grants          = config.get('search_service_grants', default=[]) -%}

  {%- if search_column is none %}
    {{ exceptions.raise_compiler_error("cortex_search_service models require a `search_column` config option (the column CORTEX SEARCH SERVICE will index and search over).") }}
  {%- endif %}
  {%- if attributes is none or attributes | length == 0 %}
    {{ exceptions.raise_compiler_error("cortex_search_service models require a non-empty `attributes` config option (list of column names) — ATTRIBUTES is required by Snowflake's CREATE CORTEX SEARCH SERVICE syntax.") }}
  {%- endif %}
  {%- if target_lag is none %}
    {{ exceptions.raise_compiler_error("cortex_search_service models require a `target_lag` config option (e.g. '1 hour', '7 days') — Snowflake has no default and requires this value on every CREATE CORTEX SEARCH SERVICE.") }}
  {%- endif %}

  -- dbt has no native 'cortex search service' relation type. 'view' is used as a
  -- placeholder for graph tracking only — the actual DDL is CREATE/ALTER CORTEX SEARCH SERVICE.
  {%- set target_relation = api.Relation.create(
      identifier=this.identifier,
      schema=this.schema,
      database=this.database,
      type='view'
  ) -%}

  {{ run_hooks(pre_hooks) }}

  {%- set _show_services_sql -%}
    SHOW CORTEX SEARCH SERVICES LIKE '{{ target_relation.identifier }}' IN SCHEMA {{ target_relation.database }}.{{ target_relation.schema }}
  {%- endset -%}
  {%- set _service_rows = run_query(_show_services_sql) -%}
  {%- set _service_exists = (_service_rows | length) > 0 -%}

  {%- if _service_exists and not should_full_refresh() %}

  {% call statement('main') %}
    {{ dbt_cortex_agent.snowflake__alter_cortex_search_service(target_relation, attributes, warehouse, target_lag, primary_key, full_index_build_interval_days, request_logging, auto_suspend, comment) }}
  {% endcall %}

  {%- else %}

  {% call statement('main') %}
    {{ dbt_cortex_agent.snowflake__create_cortex_search_service(target_relation, sql, search_column, attributes, warehouse, target_lag, primary_key, embedding_model, refresh_mode, initialize, full_index_build_interval_days, request_logging, auto_suspend, comment) }}
  {% endcall %}

  {%- endif %}

  {{ run_hooks(post_hooks) }}

  {%- if search_service_grants | length > 0 %}
  {% call statement('grants') %}
    {{ dbt_cortex_agent.snowflake__grant_cortex_search_service_usage(target_relation, search_service_grants) }}
  {% endcall %}
  {%- endif %}

  {{ return({'relations': [target_relation]}) }}

{% endmaterialization %}
