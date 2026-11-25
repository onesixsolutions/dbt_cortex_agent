-- Generates CREATE OR REPLACE AGENT DDL for a Snowflake Cortex Agent.
-- Called by the cortex_agent materialization when versioning is disabled, and on
-- `dbt run --full-refresh`.
--
-- COPY GRANTS: without it, replacing an agent drops every explicit privilege granted on it
-- (the replacement inherits only future grants), so roles granted access outside of
-- `agent_grants` silently lose the agent on the next run. With COPY GRANTS, Snowflake
-- carries all existing grants except OWNERSHIP over to the replacement in the same atomic
-- operation. It has no effect when the agent does not exist yet.
--
-- Clause order: COPY GRANTS goes AFTER COMMENT and PROFILE, immediately before
-- FROM SPECIFICATION. Snowflake's syntax reference lists it before COMMENT, but that order is
-- rejected ("syntax error ... unexpected 'comment'"); this order is the one that parses.
-- Args:
--   relation      : the target relation object (database, schema, identifier)
--   specification : compiled YAML agent spec from the model body
--   comment       : optional agent description shown in Snowflake
--   profile       : optional JSON string for display_name, avatar, and color
--   copy_grants   : keep existing grants across the replace. Defaults to true.
{% macro snowflake__create_cortex_agent(relation, specification, comment, profile, copy_grants=true) %}

  create or replace agent
    {{ relation.database }}.{{ relation.schema }}.{{ relation.identifier }}
  {%- if comment is not none %}
  comment = '{{ dbt_cortex_agent.escape_string_literal(comment) }}'
  {%- endif %}
  {%- if profile is not none %}
  profile = '{{ dbt_cortex_agent.escape_string_literal(profile) }}'
  {%- endif %}
  {%- if copy_grants %}
  copy grants
  {%- endif %}
  from specification
  $$
{{ specification | trim }}
  $$

{% endmacro %}
