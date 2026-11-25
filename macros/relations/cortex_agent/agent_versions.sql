-- Helpers that read the state of a versioned agent from SHOW VERSIONS IN AGENT and decide
-- whether the compiled specification differs from what is deployed.


-- Summarises SHOW VERSIONS IN AGENT rows. Returns a mapping:
--   has_committed : true when at least one committed version (VERSION$N) exists
--   has_live      : true when a LIVE working copy exists
--   last_version  : the highest N among VERSION$N rows, or 0
--   last_spec     : the specification of that newest committed version, or none
--   live_spec     : the specification of the LIVE working copy, or none
--
-- SHOW VERSIONS returns one row per committed version plus, when a LIVE working copy exists,
-- one row for it. The LIVE row has been observed with an empty name; Snowflake's docs call the
-- working copy LIVE, so a row named LIVE is treated the same way.
--
-- Args:
--   rows            : iterable of rows exposing `name` (and `agent_spec` when available)
--   has_spec_column : whether the rows carry an `agent_spec` column. When false the specs are
--                     returned as none and the caller cannot detect changes.
{% macro summarize_agent_versions(rows, has_spec_column=true) %}
  {%- set _ns = namespace(has_committed=false, has_live=false, last_version=0, last_spec=none, live_spec=none) -%}
  {%- for _row in rows -%}
    {%- set _name = (_row['name'] or '') | string | trim -%}
    {%- set _spec = _row['agent_spec'] if has_spec_column else none -%}
    {%- if _name == '' or (_name | upper) == 'LIVE' -%}
      {%- set _ns.has_live = true -%}
      {%- set _ns.live_spec = _spec -%}
    {%- else -%}
      {%- set _ns.has_committed = true -%}
      {%- set _number = _name.split('$')[-1] | int(-1) -%}
      {%- if _number >= _ns.last_version -%}
        {%- set _ns.last_version = _number -%}
        {%- set _ns.last_spec = _spec -%}
      {%- endif -%}
    {%- endif -%}
  {%- endfor -%}
  {{ return({
      'has_committed': _ns.has_committed,
      'has_live': _ns.has_live,
      'last_version': _ns.last_version,
      'last_spec': _ns.last_spec,
      'live_spec': _ns.live_spec
  }) }}
{% endmacro %}


-- Returns true only when the compiled specification and the deployed one are the same
-- specification.
--
-- Both sides are parsed and compared as data rather than as text: the model body is YAML,
-- while Snowflake hands the stored specification back as JSON, so the text never matches
-- even when nothing has changed. (JSON is valid YAML, so one parser reads both.)
--
-- The comparison is exact. If Snowflake were to return the specification with extra keys or
-- defaults filled in, this returns false and the caller deploys as if the spec had changed.
-- That is the safe direction: the cost of a false "changed" is one redundant version, while a
-- false "unchanged" would silently skip a deploy. Anything that cannot be parsed into a
-- mapping also counts as changed.
{% macro agent_spec_matches(compiled_spec, deployed_spec) %}
  {%- if compiled_spec is none or deployed_spec is none -%}
    {{ return(false) }}
  {%- endif -%}
  {%- set _compiled = fromyaml(compiled_spec | string, none) -%}
  {%- if deployed_spec is mapping -%}
    {%- set _deployed = deployed_spec -%}
  {%- else -%}
    {%- set _deployed = fromyaml(deployed_spec | string, none) -%}
  {%- endif -%}
  {{ return(_compiled is mapping and _deployed is mapping and _compiled == _deployed) }}
{% endmacro %}
