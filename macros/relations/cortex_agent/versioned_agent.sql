-- Macros supporting Snowflake Cortex Agent versioning.
-- Used by the cortex_agent materialization when enable_versioning=true.

-- Creates the agent only if it does not already exist.
-- On first run this initialises VERSION$1 and a LIVE working copy.
-- On subsequent runs the CREATE is a no-op; spec changes go through
-- snowflake__alter_cortex_agent_live_spec instead.
{% macro snowflake__create_cortex_agent_if_not_exists(relation, specification, comment, profile) %}

  create agent if not exists
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


-- Recreates the LIVE working copy from the last committed version.
-- Required before MODIFY LIVE VERSION on any run after the first COMMIT,
-- because COMMIT consumes the LIVE version and does not recreate it automatically.
{% macro snowflake__add_cortex_agent_live_version(relation) %}

  alter agent
    {{ relation.database }}.{{ relation.schema }}.{{ relation.identifier }}
  add live version from last

{% endmacro %}


-- Pushes the latest compiled spec into the mutable LIVE version.
-- Runs on every dbt run when versioning is enabled, keeping LIVE current.
{% macro snowflake__alter_cortex_agent_live_spec(relation, specification) %}

  alter agent
    {{ relation.database }}.{{ relation.schema }}.{{ relation.identifier }}
  modify live version set specification =
  $$
{{ specification | trim }}
  $$

{% endmacro %}


-- Snapshots the current LIVE version into a new immutable named version
-- (VERSION$2, VERSION$3, …). Called when auto_commit=true.
{% macro snowflake__commit_cortex_agent_version(relation, version_comment) %}

  alter agent
    {{ relation.database }}.{{ relation.schema }}.{{ relation.identifier }}
  commit
  {%- if version_comment is not none %}
  comment = '{{ version_comment }}'
  {%- endif %}

{% endmacro %}
