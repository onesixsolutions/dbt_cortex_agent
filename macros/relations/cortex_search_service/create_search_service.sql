-- Generates and executes CREATE OR REPLACE CORTEX SEARCH SERVICE DDL for a Snowflake
-- Cortex Search Service, using the single-index (ON + ATTRIBUTES) syntax only.
-- Called by the cortex_search_service materialization on the first run for a given
-- service, or on any `dbt run --full-refresh`.
-- Args:
--   relation                        : the target relation object (database, schema, identifier)
--   query                           : compiled SELECT query from the model body (the AS <query> clause)
--   search_column                   : required — column to search over
--   attributes                      : required — list of attribute column names
--   warehouse                       : required — warehouse name used to (re)build the index
--   target_lag                      : required — e.g. '1 hour', '7 days'
--   primary_key                     : optional list of primary key column names
--   embedding_model                 : optional — immutable after create
--   refresh_mode                    : optional — INCREMENTAL|FULL, immutable after create
--   initialize                      : optional — ON_CREATE|ON_SCHEDULE, immutable after create
--   full_index_build_interval_days  : optional int
--   request_logging                 : optional bool
--   auto_suspend                    : optional int (seconds, min 1800)
--   comment                         : optional string
{% macro snowflake__create_cortex_search_service(relation, query, search_column, attributes, warehouse, target_lag, primary_key, embedding_model, refresh_mode, initialize, full_index_build_interval_days, request_logging, auto_suspend, comment) %}

  create or replace cortex search service
    {{ relation.database }}.{{ relation.schema }}.{{ relation.identifier }}
  on {{ search_column }}
  {%- if primary_key is not none and primary_key | length > 0 %}
  primary key ({{ primary_key | join(', ') }})
  {%- endif %}
  attributes {{ attributes | join(', ') }}
  warehouse = {{ warehouse }}
  target_lag = '{{ target_lag }}'
  {%- if embedding_model is not none %}
  embedding_model = '{{ embedding_model }}'
  {%- endif %}
  {%- if refresh_mode is not none %}
  refresh_mode = {{ refresh_mode }}
  {%- endif %}
  {%- if initialize is not none %}
  initialize = {{ initialize }}
  {%- endif %}
  {%- if full_index_build_interval_days is not none %}
  full_index_build_interval_days = {{ full_index_build_interval_days }}
  {%- endif %}
  {%- if request_logging is not none %}
  request_logging = {{ request_logging | lower }}
  {%- endif %}
  {%- if auto_suspend is not none %}
  auto_suspend = {{ auto_suspend }}
  {%- endif %}
  {%- if comment is not none %}
  comment = '{{ comment }}'
  {%- endif %}
  as (
{{ query }}
  )

{% endmacro %}
