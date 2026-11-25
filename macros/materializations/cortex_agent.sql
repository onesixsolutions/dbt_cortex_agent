-- Custom dbt materialization for Snowflake Cortex Agents.
-- The model body must be a valid Snowflake agent YAML specification.
-- With versioning (the default) the agent is created once with CREATE AGENT IF NOT EXISTS and
-- each later run that changes the specification updates and commits a new version. With
-- enable_versioning=false it is replaced with CREATE OR REPLACE AGENT ... FROM SPECIFICATION
-- $$ ... $$ on every run; a versioned agent is replaced only on --full-refresh with
-- replace_on_full_refresh=true.
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
--                                        dbt run --full-refresh does NOT replace a versioned agent
--                                        unless replace_on_full_refresh=true (see below).
--   replace_on_full_refresh (bool, optional) : allow `dbt run --full-refresh` to replace a
--                                        versioned agent with CREATE OR REPLACE AGENT. Defaults
--                                        to false, because a replace permanently deletes the
--                                        agent's version history (and what is attached to the
--                                        old object), and --full-refresh is routinely run across
--                                        a whole project for other reasons. When false, a full
--                                        refresh deploys a versioned agent like any other run.
--   auto_commit (bool, optional)      : when enable_versioning=true, automatically snapshot the
--                                       LIVE version into a new named version after a run that
--                                       changed the specification. Defaults to true. Set to
--                                       false to accumulate changes in LIVE without committing,
--                                       then commit manually.
--   commit_only_on_change (bool, optional) : when enable_versioning=true, compare the compiled
--                                       specification with the deployed one and skip the update
--                                       and commit when they are the same, so a run that changes
--                                       nothing does not add a version. Defaults to true. Set to
--                                       false to commit a new version on every run.
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
  {%- set commit_only_on_change  = dbt_cortex_agent.get_package_config('commit_only_on_change', default=true) -%}
  {%- set replace_on_full_refresh = dbt_cortex_agent.get_package_config('replace_on_full_refresh', default=false) -%}

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

  {%- do dbt_cortex_agent.warn_if_native_grants('agent_grants') -%}
  {%- do dbt_cortex_agent.assert_no_dollar_quote(sql, 'cortex_agent') -%}

  {#- A versioned agent is only ever replaced on an explicit opt-in. CREATE OR REPLACE AGENT
      resets the agent to VERSION$1, permanently deleting its version history, and
      --full-refresh is something people run across a whole project to rebuild incremental
      models. Without replace_on_full_refresh a full refresh therefore deploys the agent the
      normal, history-preserving way. -#}
  {%- set _full_refresh = should_full_refresh() -%}
  {%- set _replace_agent = (not enable_versioning) or (_full_refresh and replace_on_full_refresh) -%}
  {%- if _full_refresh and enable_versioning and not replace_on_full_refresh -%}
    {{ log("dbt_cortex_agent: --full-refresh does not replace versioned agent " ~ this.identifier ~ " (that would delete its version history); deploying it as a normal run. Set replace_on_full_refresh: true to replace it.", info=true) }}
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

  {%- if not _replace_agent %}

  {# Creates the agent on the first run; a no-op on every later run. #}
  {% call statement('main') %}
    {{ dbt_cortex_agent.snowflake__create_cortex_agent_if_not_exists(target_relation, sql, comment, profile) }}
  {% endcall %}

  {# COMMENT and PROFILE belong to the agent, not to a version, and CREATE ... IF NOT EXISTS
     ignores them once the agent exists — so apply them explicitly on every run. #}
  {%- for _property_sql in dbt_cortex_agent.snowflake__alter_cortex_agent_properties(target_relation, comment, profile) %}
  {% call statement('agent_property_' ~ loop.index) %}
    {{ _property_sql }}
  {% endcall %}
  {%- endfor %}

  {# Read the agent's versions (it exists by now) to learn:
       - whether a LIVE working copy exists. COMMIT consumes LIVE, so after a committed run
         there is none and it must be restored before it can be modified; adding one when it
         already exists fails with 099106 ("There is already a live version").
       - what specification is deployed, to tell whether this run changes anything. #}
  {%- set _show_versions_sql -%}
    SHOW VERSIONS IN AGENT {{ target_relation.database }}.{{ target_relation.schema }}.{{ target_relation.identifier }}
  {%- endset -%}
  {%- set _version_rows = run_query(_show_versions_sql) -%}
  {%- set _has_spec_column = 'agent_spec' in _version_rows.column_names -%}
  {%- set _versions = dbt_cortex_agent.summarize_agent_versions(_version_rows.rows, _has_spec_column) -%}
  {%- set _has_committed_versions = _versions['has_committed'] -%}
  {%- set _has_live_version = _versions['has_live'] -%}

  {# What "deployed" means depends on the mode. With auto_commit the run's outcome is a
     committed version, so compare with the newest one; without it the outcome is the LIVE
     working copy, so compare with that. #}
  {%- if auto_commit -%}
    {%- set _deployed_spec = _versions['last_spec'] if _has_committed_versions else _versions['live_spec'] -%}
  {%- else -%}
    {%- set _deployed_spec = _versions['live_spec'] if _has_live_version else _versions['last_spec'] -%}
  {%- endif -%}
  {%- set _spec_unchanged = commit_only_on_change and dbt_cortex_agent.agent_spec_matches(sql, _deployed_spec) -%}

  {%- if _spec_unchanged %}

  {{ log("dbt_cortex_agent: specification of agent " ~ target_relation.identifier ~ " is unchanged; no new version created.", info=true) }}

  {%- else %}

  {%- if _has_committed_versions and not _has_live_version %}
  {# Restore LIVE from the last committed version so MODIFY LIVE VERSION has a target. #}
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
  {%- endif %}

  {%- endif %}

  {%- if auto_commit and set_default_version and (_has_committed_versions or not _spec_unchanged) %}
  {# COMMIT does not move the DEFAULT pointer. Promote explicitly so the newest version is
     the one users get. This runs even when nothing was committed, so that an agent whose
     pointer was pinned out-of-band (e.g. via Snowsight) is un-stuck by the next run. #}
  {% call statement('set_default_version') %}
    {{ dbt_cortex_agent.snowflake__set_cortex_agent_default_version(target_relation) }}
  {% endcall %}
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
