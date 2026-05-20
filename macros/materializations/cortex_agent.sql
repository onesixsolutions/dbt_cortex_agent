-- Copyright 2025 OneSix Solutions
-- SPDX-License-Identifier: Apache-2.0
--
-- Custom dbt materialization for Snowflake Cortex Agents.
-- The model body must be a valid Snowflake agent YAML specification.
-- The materialization wraps it in CREATE OR REPLACE AGENT ... FROM SPECIFICATION $$ ... $$.
--
-- Config options:
--   comment (string, optional) : agent-level comment visible in Snowflake
--   profile (string, optional) : JSON object with display_name, avatar, and color

{% materialization cortex_agent, adapter='snowflake' %}

  {%- set comment = config.get('comment', default=none) -%}
  {%- set profile = config.get('profile', default=none) -%}

  {%- set target_relation = api.Relation.create(
      identifier=this.identifier,
      schema=this.schema,
      database=this.database,
      type='view'
  ) -%}

  {{ run_hooks(pre_hooks) }}

  {% call statement('main') %}
    {{ dbt_cortex_agent.snowflake__create_cortex_agent(target_relation, sql, comment, profile) }}
  {% endcall %}

  {{ run_hooks(post_hooks) }}

  {{ return({'relations': [target_relation]}) }}

{% endmaterialization %}
