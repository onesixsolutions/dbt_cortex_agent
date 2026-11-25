-- Reads a dbt_cortex_agent config option for the current model.
--
-- Lookup order:
--   1. the key under `meta`      -- config(meta={'comment': '...'})  (works on dbt v1 and v2)
--   2. the top-level config key  -- config(comment='...')            (dbt v1 style)
--
-- Why both: the dbt v2 engine validates config keys strictly and rejects any key it does not
-- know (error dbt1060, "Ignored unexpected key"), so package-specific options such as
-- `comment`, `agent_grants`, or `search_column` can no longer live at the top level of
-- config() / schema.yml there. `meta` is the supported home for custom keys on every dbt
-- version, so options set under `meta` work everywhere. Top-level keys keep working on
-- dbt v1, so existing projects need no change until they move to v2.
--
-- `meta` is checked first because calling config.get() for a key that only exists under
-- `meta` makes dbt (v1.10+ and v2) log a "use config.meta_get()" warning on every run.
-- A `meta` value therefore wins over a top-level value when both are set. `default` is
-- returned when the option is absent (or explicitly null) in both places.
{% macro get_package_config(key, default=none) %}
  {%- set _value = none -%}
  {%- set _meta = config.get('meta', default=none) -%}
  {%- if _meta is mapping and key in _meta -%}
    {%- set _value = _meta[key] -%}
  {%- else -%}
    {%- set _value = config.get(key, default=none) -%}
  {%- endif -%}
  {{ return(default if _value is none else _value) }}
{% endmacro %}
