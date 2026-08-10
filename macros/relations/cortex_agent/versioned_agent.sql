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


-- Promotes the newest committed version to DEFAULT — the version end users and
-- Snowsight see as "In use".
--
-- Why this is required: COMMIT creates a version but does NOT move the DEFAULT
-- pointer. Snowflake only tracks the latest committed version *implicitly*, and
-- that implicit behaviour stops the moment DEFAULT_VERSION is set explicitly by
-- anything out-of-band (notably Snowsight's Publish button). From then on every
-- dbt deploy commits a version that no user ever sees. Setting it explicitly on
-- each commit makes promotion deterministic and self-healing: a pinned agent is
-- un-stuck by the next dbt run.
--
-- 'LAST' is used rather than a computed VERSION$N so the statement needs no version
-- bookkeeping and stays idempotent. Note the quotes are required: the unquoted forms
-- (LAST, VERSION$3, "VERSION$3") are all rejected with a SQL compilation error, despite
-- what the Snowflake docs show — only the single-quoted string form parses.
{% macro snowflake__set_cortex_agent_default_version(relation) %}

  alter agent
    {{ relation.database }}.{{ relation.schema }}.{{ relation.identifier }}
  set default_version = 'LAST'

{% endmacro %}
