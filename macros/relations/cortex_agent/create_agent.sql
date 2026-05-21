-- Generates and executes CREATE OR REPLACE AGENT DDL for a Snowflake Cortex Agent.
-- Called by the cortex_agent materialization on every dbt run.
-- Args:
--   relation      : the target relation object (database, schema, identifier)
--   specification : compiled YAML agent spec from the model body
--   comment       : optional agent description shown in Snowflake
--   profile       : optional JSON string for display_name, avatar, and color
{% macro snowflake__create_cortex_agent(relation, specification, comment, profile) %}

  create or replace agent
    {{ relation.database }}.{{ relation.schema }}.{{ relation.identifier }}
  {%- if comment is not none %}
  comment = '{{ comment }}'
  {%- endif %}
  {%- if profile is not none %}
  profile = '{{ profile }}'
  {%- endif %}
  from specification
  $$
{{ specification | trim }}
  $$

{% endmacro %}
