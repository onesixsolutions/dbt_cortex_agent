{{ config(materialized='view') }}
{#- Versioned-agent helpers: reading SHOW VERSIONS rows, detecting an unchanged specification,
    and the object-level COMMENT / PROFILE statements. -#}
{% if execute %}
{%- set rel = test_relation() -%}

-- summarize_agent_versions
{%- set fresh = dbt_cortex_agent.summarize_agent_versions([
    {'name': 'VERSION$1', 'agent_spec': '{"a": 1}'},
    {'name': '',          'agent_spec': '{"a": 2}'}
]) -%}
{{ assert_true('summary: committed version detected', fresh['has_committed']) }}
{{ assert_true('summary: an empty name is the LIVE working copy', fresh['has_live']) }}
{{ assert_equal('summary: last version number', fresh['last_version'], 1) }}
{{ assert_equal('summary: last committed spec', fresh['last_spec'], '{"a": 1}') }}
{{ assert_equal('summary: live spec', fresh['live_spec'], '{"a": 2}') }}

{%- set committed_only = dbt_cortex_agent.summarize_agent_versions([
    {'name': 'VERSION$2',  'agent_spec': 'two'},
    {'name': 'VERSION$10', 'agent_spec': 'ten'},
    {'name': 'VERSION$9',  'agent_spec': 'nine'}
]) -%}
{{ assert_true('summary: no LIVE after a commit consumed it', not committed_only['has_live']) }}
{{ assert_equal('summary: newest version is chosen numerically, not alphabetically', committed_only['last_version'], 10) }}
{{ assert_equal('summary: spec of the newest version', committed_only['last_spec'], 'ten') }}
{{ assert_true('summary: live spec is none without a LIVE row', committed_only['live_spec'] is none) }}

{%- set named_live = dbt_cortex_agent.summarize_agent_versions([{'name': 'live', 'agent_spec': 'x'}, {'name': none, 'agent_spec': 'y'}]) -%}
{{ assert_true('summary: a row named LIVE (any case) is the working copy', named_live['has_live']) }}
{{ assert_true('summary: LIVE rows are not counted as committed', not named_live['has_committed']) }}

{%- set empty = dbt_cortex_agent.summarize_agent_versions([]) -%}
{{ assert_true('summary: no rows means nothing committed and no LIVE', not empty['has_committed'] and not empty['has_live']) }}
{{ assert_equal('summary: no rows gives version 0', empty['last_version'], 0) }}

{%- set no_spec = dbt_cortex_agent.summarize_agent_versions([{'name': 'VERSION$3'}, {'name': ''}], false) -%}
{{ assert_true('summary: works without an agent_spec column', no_spec['has_committed'] and no_spec['has_live']) }}
{{ assert_true('summary: specs are none without an agent_spec column', no_spec['last_spec'] is none and no_spec['live_spec'] is none) }}

-- agent_spec_matches
{%- set yaml_spec -%}
models:
  orchestration: auto
orchestration:
  budget:
    seconds: 30
    tokens: 8000
tools:
  - tool_spec:
      type: generic
      name: t1
  - tool_spec:
      type: generic
      name: t2
{%- endset -%}
{%- set same_json = '{"tools": [{"tool_spec": {"name": "t1", "type": "generic"}}, {"tool_spec": {"type": "generic", "name": "t2"}}], "orchestration": {"budget": {"tokens": 8000, "seconds": 30}}, "models": {"orchestration": "auto"}}' -%}
{{ assert_true('match: YAML body equals the same spec returned as JSON with keys reordered', dbt_cortex_agent.agent_spec_matches(yaml_spec, same_json)) }}
{{ assert_true('match: a spec equals itself', dbt_cortex_agent.agent_spec_matches(yaml_spec, yaml_spec)) }}
{{ assert_true('match: surrounding whitespace does not matter', dbt_cortex_agent.agent_spec_matches('\n\n' ~ yaml_spec ~ '\n  \n', same_json)) }}
{{ assert_true('match: an already-parsed mapping is accepted', dbt_cortex_agent.agent_spec_matches('a: 1', {'a': 1})) }}
{{ assert_true('differ: a changed value', not dbt_cortex_agent.agent_spec_matches(yaml_spec, same_json | replace('8000', '9000'))) }}
{{ assert_true('differ: a changed string', not dbt_cortex_agent.agent_spec_matches(yaml_spec, same_json | replace('"auto"', '"claude"'))) }}
{{ assert_true('differ: tools in a different order', not dbt_cortex_agent.agent_spec_matches(yaml_spec, same_json | replace('"t1"', '"tX"') | replace('"t2"', '"t1"') | replace('"tX"', '"t2"'))) }}
{{ assert_true('differ: a key present only in the deployed spec (removed from the model)', not dbt_cortex_agent.agent_spec_matches('a: 1', '{"a": 1, "b": 2}')) }}
{{ assert_true('differ: a key present only in the model (added to the model)', not dbt_cortex_agent.agent_spec_matches('a: 1\nb: 2', '{"a": 1}')) }}
{{ assert_true('differ: number versus string', not dbt_cortex_agent.agent_spec_matches('a: 5', '{"a": "5"}')) }}
{{ assert_true('differ: no deployed spec', not dbt_cortex_agent.agent_spec_matches(yaml_spec, none)) }}
{{ assert_true('differ: empty deployed spec', not dbt_cortex_agent.agent_spec_matches(yaml_spec, '')) }}
{{ assert_true('differ: deployed spec is not a mapping', not dbt_cortex_agent.agent_spec_matches(yaml_spec, '[1, 2]')) }}
{{ assert_true('differ: model body is not a mapping', not dbt_cortex_agent.agent_spec_matches('just text', 'just text')) }}

-- object-level properties
{{ assert_equal('properties: comment and profile are separate statements',
    dbt_cortex_agent.snowflake__alter_cortex_agent_properties(rel, 'my comment', '{"display_name": "Bot"}'),
    ["alter agent DB.SCH.OBJ set comment = 'my comment'",
     "alter agent DB.SCH.OBJ set profile = '{\"display_name\": \"Bot\"}'"]) }}
{{ assert_equal('properties: only comment', dbt_cortex_agent.snowflake__alter_cortex_agent_properties(rel, 'c', none), ["alter agent DB.SCH.OBJ set comment = 'c'"]) }}
{{ assert_equal('properties: only profile', dbt_cortex_agent.snowflake__alter_cortex_agent_properties(rel, none, 'p'), ["alter agent DB.SCH.OBJ set profile = 'p'"]) }}
{{ assert_equal('properties: nothing configured means no statements', dbt_cortex_agent.snowflake__alter_cortex_agent_properties(rel, none, none), []) }}
{{ assert_equal('properties: apostrophes are escaped',
    dbt_cortex_agent.snowflake__alter_cortex_agent_properties(rel, "It's mine", none),
    ["alter agent DB.SCH.OBJ set comment = 'It''s mine'"]) }}
{{ assert_equal('properties: an empty comment is still applied', dbt_cortex_agent.snowflake__alter_cortex_agent_properties(rel, '', none), ["alter agent DB.SCH.OBJ set comment = ''"]) }}

-- $$ guard: a body without $$ passes silently (the failing cases are in test_expected_errors)
{%- do dbt_cortex_agent.assert_no_dollar_quote('costs $5 or $ $ or $1$', 'cortex_agent') -%}
{{ assert_true('dollar guard: single dollar signs are allowed', true) }}
{% endif %}
select 1 as ok
