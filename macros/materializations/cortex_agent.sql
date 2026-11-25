-- Custom dbt materialization for Snowflake Cortex Agents.
-- The model body must be a valid Snowflake agent YAML specification.
-- With versioning (the default) the agent is created once with CREATE AGENT IF NOT EXISTS and
-- each later run updates and commits a new version; with enable_versioning=false, or on
-- --full-refresh, it is replaced with CREATE OR REPLACE AGENT ... FROM SPECIFICATION $$ ... $$.
--
-- Config options:
--   comment (string, optional)        : agent-level comment visible in Snowflake
--   profile (string, optional)        : JSON object with display_name, avatar, and color
--   agent_grants (list or map, optional) : who gets access to the agent. A list of role names
--                                       grants USAGE to each; a map of privilege -> roles
--                                       (e.g. {'usage': [...], 'monitor': [...]}) grants any
--                                       agent privilege. Prefix a name with 'database role '
--                                       to grant to a database role.
--                                       When create_feedback_table=true the USAGE grantees are
--                                       also granted USAGE on the AGENT_SUBMIT_FEEDBACK
--                                       procedure, so they can actually call the feedback tool.
--   revoke_unlisted_grants (bool, optional) : revoke privileges held on the agent by account
--                                       roles that are not listed in agent_grants, making
--                                       agent_grants the full definition of access rather than
--                                       an additive list. Defaults to false.
--   copy_grants (bool, optional)      : add COPY GRANTS to CREATE OR REPLACE AGENT so grants
--                                       made on the agent outside of dbt survive a replace
--                                       (enable_versioning=false, or --full-refresh).
--                                       Defaults to true. The versioned path never replaces
--                                       the agent, so it keeps grants regardless.
--   create_feedback_table (bool, optional) : whether to create the feedback table and procedure.
--                                            Defaults to false. Set to true to enable.
--   feedback_schema (string, optional) : schema for the feedback table and AGENT_SUBMIT_FEEDBACK
--                                        procedure. Accepts 'SCHEMA' or 'DB.SCHEMA'. Defaults to
--                                        the agent's own database and schema.
--   feedback_table (string, optional) : fully-qualified override for the feedback table name.
--                                       Defaults to {feedback_schema}.AGENT_FEEDBACK.
--                                       Creates the table (if absent) and a stored procedure
--                                       named AGENT_SUBMIT_FEEDBACK on every dbt run.
--   feedback_execute_as (string, optional) : execution rights for the AGENT_SUBMIT_FEEDBACK procedure.
--                                            Accepts 'caller' (default) or 'owner'.
--                                            Use 'caller' to capture the end user via current_user().
--                                            Use 'owner' if the calling role lacks INSERT on the feedback table.
--   enable_versioning (bool, optional) : opt into Snowflake agent versioning. Defaults to true.
--                                        When true, uses CREATE AGENT IF NOT EXISTS + ALTER AGENT
--                                        MODIFY LIVE VERSION instead of CREATE OR REPLACE AGENT,
--                                        preserving version history across runs.
--                                        Set to false in dev environments to skip versioning overhead.
--                                        dbt run --full-refresh falls back to CREATE OR REPLACE,
--                                        resetting all version history.
--   auto_commit (bool, optional)      : when enable_versioning=true, automatically snapshot the
--                                       LIVE version into a new named version after each run.
--                                       Defaults to true. Set to false to accumulate changes in
--                                       LIVE without committing, then commit manually.
--   version_comment (string, optional) : comment attached to the committed version snapshot.
--                                        Only used when enable_versioning=true and auto_commit=true.
--   set_default_version (bool, optional) : promote the newly committed version to DEFAULT so
--                                          end users (and Snowsight's "In use") get it.
--                                          Defaults to true. Only used when enable_versioning=true
--                                          and auto_commit=true.
--                                          COMMIT alone does NOT move the DEFAULT pointer: Snowflake
--                                          only follows the latest version implicitly, and stops doing
--                                          so as soon as DEFAULT_VERSION is set out-of-band (e.g. by
--                                          Snowsight's Publish button) — after which every dbt deploy
--                                          is invisible to users. Set false only if you promote
--                                          versions yourself (e.g. staged releases via aliases).

{% materialization cortex_agent, adapter='snowflake' %}

  {%- set comment                = dbt_cortex_agent.get_package_config('comment', default=none) -%}
  {%- set profile                = dbt_cortex_agent.get_package_config('profile', default=none) -%}
  {%- set agent_grants           = dbt_cortex_agent.get_package_config('agent_grants', default=[]) -%}
  {%- set copy_grants            = dbt_cortex_agent.get_package_config('copy_grants', default=true) -%}
  {%- set revoke_unlisted_grants = dbt_cortex_agent.get_package_config('revoke_unlisted_grants', default=false) -%}
  {%- set create_feedback_table  = dbt_cortex_agent.get_package_config('create_feedback_table', default=false) -%}
  {%- set feedback_schema_config = dbt_cortex_agent.get_package_config('feedback_schema', default=none) -%}
  {%- set feedback_table         = dbt_cortex_agent.get_package_config('feedback_table', default=none) -%}
  {%- set feedback_execute_as    = dbt_cortex_agent.get_package_config('feedback_execute_as', default='caller') -%}
  {%- set enable_versioning      = dbt_cortex_agent.get_package_config('enable_versioning', default=true) -%}
  {%- set auto_commit            = dbt_cortex_agent.get_package_config('auto_commit', default=true) -%}
  {%- set version_comment        = dbt_cortex_agent.get_package_config('version_comment', default=none) -%}
  {%- set set_default_version    = dbt_cortex_agent.get_package_config('set_default_version', default=true) -%}

  {%- set target_relation = api.Relation.create(
      identifier=this.identifier,
      schema=this.schema,
      database=this.database,
      type='view'
  ) -%}

  {%- if feedback_schema_config is not none -%}
    {%- set _parts = feedback_schema_config.split('.') -%}
    {%- if _parts | length == 2 -%}
      {%- set feedback_db     = _parts[0] -%}
      {%- set feedback_schema = _parts[1] -%}
    {%- else -%}
      {%- set feedback_db     = target_relation.database -%}
      {%- set feedback_schema = feedback_schema_config -%}
    {%- endif -%}
  {%- else -%}
    {%- set feedback_db     = target_relation.database -%}
    {%- set feedback_schema = target_relation.schema -%}
  {%- endif -%}

  {%- if create_feedback_table and feedback_table is none -%}
    {%- set feedback_table = feedback_db ~ '.' ~ feedback_schema ~ '.AGENT_FEEDBACK' -%}
  {%- endif -%}

  {{ run_hooks(pre_hooks) }}

  {%- if create_feedback_table and feedback_table is not none %}
  {% call statement('feedback_table') %}
    {{ dbt_cortex_agent.snowflake__create_feedback_table(feedback_table) }}
  {% endcall %}

  {% call statement('feedback_procedure') %}
    {{ dbt_cortex_agent.snowflake__create_feedback_procedure(feedback_db, feedback_schema, feedback_table, feedback_execute_as) }}
  {% endcall %}
  {%- endif %}

  {%- if enable_versioning and not should_full_refresh() %}

  {# Inspect existing versions to decide whether LIVE needs (re)creating.
     SHOW VERSIONS returns one row per committed version (name = VERSION$N) plus, when a
     LIVE working copy exists, one row for it. That row has been observed with an empty name;
     Snowflake's docs refer to the working copy as LIVE, so a row named LIVE is treated the
     same way in case the output changes to match.
       - no committed versions  : first run — LIVE does not exist yet, skip ADD LIVE VERSION.
       - committed, no LIVE     : the normal steady state after COMMIT consumed LIVE — restore it.
       - committed, LIVE exists : ADD LIVE VERSION would fail with 099106 ("There is already a
                                  live version"), which is the state a prior CREATE OR REPLACE
                                  (e.g. dbt run --full-refresh) leaves behind — skip the add and
                                  modify the existing LIVE in place. #}
  {%- set _show_agents_sql -%}
    SHOW AGENTS LIKE '{{ target_relation.identifier }}' IN SCHEMA {{ target_relation.database }}.{{ target_relation.schema }}
  {%- endset -%}
  {%- set _agent_rows = run_query(_show_agents_sql) -%}
  {%- set _ns = namespace(has_committed=false, has_live=false) -%}
  {#- Match the name exactly: LIKE treats `_` as a wildcard, so the SHOW can return a
      different agent whose name merely fits the pattern. -#}
  {%- if dbt_cortex_agent.find_show_row(_agent_rows.rows, target_relation.identifier) is not none -%}
    {%- set _show_versions_sql -%}
      SHOW VERSIONS IN AGENT {{ target_relation.database }}.{{ target_relation.schema }}.{{ target_relation.identifier }}
    {%- endset -%}
    {%- set _version_rows = run_query(_show_versions_sql) -%}
    {%- for _r in _version_rows.rows -%}
      {%- set _version_name = (_r['name'] or '') | string | trim -%}
      {%- if _version_name == '' or (_version_name | upper) == 'LIVE' -%}
        {%- set _ns.has_live = true -%}
      {%- else -%}
        {%- set _ns.has_committed = true -%}
      {%- endif -%}
    {%- endfor -%}
  {%- endif -%}
  {%- set _has_committed_versions = _ns.has_committed -%}
  {%- set _has_live_version = _ns.has_live -%}

  {% call statement('main') %}
    {{ dbt_cortex_agent.snowflake__create_cortex_agent_if_not_exists(target_relation, sql, comment, profile) }}
  {% endcall %}

  {%- if _has_committed_versions and not _has_live_version %}
  {# COMMIT consumes LIVE and does not recreate it. Explicitly restore LIVE from the
     last committed version before modifying, so MODIFY LIVE VERSION has a target.
     Skipped when a LIVE already exists — adding a second one errors with 099106. #}
  {% call statement('add_live') %}
    {{ dbt_cortex_agent.snowflake__add_cortex_agent_live_version(target_relation) }}
  {% endcall %}
  {%- endif %}

  {% call statement('update_live') %}
    {{ dbt_cortex_agent.snowflake__alter_cortex_agent_live_spec(target_relation, sql) }}
  {% endcall %}

  {%- if auto_commit %}
  {% call statement('commit_version') %}
    {{ dbt_cortex_agent.snowflake__commit_cortex_agent_version(target_relation, version_comment) }}
  {% endcall %}

  {%- if set_default_version %}
  {# COMMIT does not move the DEFAULT pointer. Promote explicitly so the version just
     deployed is the one users get, and so an agent whose pointer was pinned
     out-of-band (e.g. via Snowsight) is un-stuck on the next run. #}
  {% call statement('set_default_version') %}
    {{ dbt_cortex_agent.snowflake__set_cortex_agent_default_version(target_relation) }}
  {% endcall %}
  {%- endif %}
  {%- endif %}

  {%- else %}

  {% call statement('main') %}
    {{ dbt_cortex_agent.snowflake__create_cortex_agent(target_relation, sql, comment, profile, copy_grants) }}
  {% endcall %}

  {%- endif %}

  {{ run_hooks(post_hooks) }}

  {# Revoke before granting, so a listed grant always ends the run in place. #}
  {%- if revoke_unlisted_grants %}
  {%- set _agent_name = target_relation.database ~ '.' ~ target_relation.schema ~ '.' ~ target_relation.identifier -%}
  {%- for _revoke_sql in dbt_cortex_agent.get_revoke_unlisted_grant_statements('agent', _agent_name, agent_grants, 'agent_grants') %}
  {% call statement('revoke_' ~ loop.index) %}
    {{ _revoke_sql }}
  {% endcall %}
  {%- endfor %}
  {%- endif %}

  {%- for _grant_sql in dbt_cortex_agent.snowflake__grant_cortex_agent_usage(target_relation, agent_grants) %}
  {% call statement('grant_' ~ loop.index) %}
    {{ _grant_sql }}
  {% endcall %}
  {%- endfor %}

  {%- if create_feedback_table and feedback_table is not none %}
  {%- set _feedback_grantees = dbt_cortex_agent.normalize_grants(agent_grants, 'agent_grants').get('usage', []) -%}
  {%- for _grant_sql in dbt_cortex_agent.snowflake__grant_feedback_procedure_usage(feedback_db, feedback_schema, _feedback_grantees) %}
  {% call statement('grant_feedback_' ~ loop.index) %}
    {{ _grant_sql }}
  {% endcall %}
  {%- endfor %}
  {%- endif %}

  {{ return({'relations': [target_relation]}) }}

{% endmaterialization %}
