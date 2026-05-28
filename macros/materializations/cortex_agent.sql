-- Custom dbt materialization for Snowflake Cortex Agents.
-- The model body must be a valid Snowflake agent YAML specification.
-- The materialization wraps it in CREATE OR REPLACE AGENT ... FROM SPECIFICATION $$ ... $$.
--
-- Config options:
--   comment (string, optional)        : agent-level comment visible in Snowflake
--   profile (string, optional)        : JSON object with display_name, avatar, and color
--   agent_grants (list, optional)     : list of role names to grant USAGE on the agent
--   create_feedback_table (bool, optional) : whether to create the feedback table and procedure.
--                                            Defaults to true. Set to false to skip.
--   feedback_table (string, optional) : fully-qualified table name for user feedback.
--                                       Defaults to {DB}.{SCHEMA}.{AGENT}_FEEDBACK.
--                                       Creates the table (if absent) and a stored procedure
--                                       named {agent}_SUBMIT_FEEDBACK on every dbt run.

{% materialization cortex_agent, adapter='snowflake' %}

  {%- set comment                = config.get('comment', default=none) -%}
  {%- set profile                = config.get('profile', default=none) -%}
  {%- set agent_grants           = config.get('agent_grants', default=[]) -%}
  {%- set create_feedback_table  = config.get('create_feedback_table', default=true) -%}
  {%- set feedback_table         = config.get('feedback_table', default=none) -%}

  {%- set target_relation = api.Relation.create(
      identifier=this.identifier,
      schema=this.schema,
      database=this.database,
      type='view'
  ) -%}

  {%- if create_feedback_table and feedback_table is none -%}
    {%- set feedback_table = target_relation.database ~ '.' ~ target_relation.schema ~ '.' ~ (target_relation.identifier | upper) ~ '_FEEDBACK' -%}
  {%- endif -%}

  {{ run_hooks(pre_hooks) }}

  {%- if create_feedback_table and feedback_table is not none %}
  {% call statement('feedback_table') %}
    {{ dbt_cortex_agent.snowflake__create_feedback_table(feedback_table) }}
  {% endcall %}

  {% call statement('feedback_procedure') %}
    {{ dbt_cortex_agent.snowflake__create_feedback_procedure(target_relation, feedback_table) }}
  {% endcall %}
  {%- endif %}

  {% call statement('main') %}
    {{ dbt_cortex_agent.snowflake__create_cortex_agent(target_relation, sql, comment, profile) }}
  {% endcall %}

  {{ run_hooks(post_hooks) }}

  {%- if agent_grants | length > 0 %}
  {% call statement('grants') %}
    {{ dbt_cortex_agent.snowflake__grant_cortex_agent_usage(target_relation, agent_grants) }}
  {% endcall %}
  {%- endif %}

  {{ return({'relations': [target_relation]}) }}

{% endmaterialization %}
