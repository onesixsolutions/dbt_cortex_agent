-- Returns the row of a SHOW <objects> LIKE '<name>' result whose `name` is exactly the given
-- identifier, or none when there is no such row.
--
-- Why not just test "did SHOW ... LIKE return any rows": LIKE is a pattern match, and `_` is
-- a single-character wildcard. Object names are full of underscores, so
-- SHOW ... LIKE 'SALES_AGENT' also matches an object named SALESXAGENT. Treating that as
-- "the object exists" sends the materialization down the ALTER path for an object that is
-- not there. Matching the returned name exactly closes the gap.
--
-- The comparison is case-insensitive unless the names are identical as written, since an
-- unquoted identifier is stored upper-cased while dbt may carry it in any case.
-- Args:
--   rows       : iterable of rows exposing `name` (e.g. `run_query(...).rows`)
--   identifier : the object name to look for
{% macro find_show_row(rows, identifier) %}
  {%- set _ns = namespace(match=none) -%}
  {%- set _wanted = identifier | string -%}
  {%- for _row in rows -%}
    {%- set _name = _row['name'] | string -%}
    {%- if _ns.match is none and (_name == _wanted or (_name | upper) == (_wanted | upper)) -%}
      {%- set _ns.match = _row -%}
    {%- endif -%}
  {%- endfor -%}
  {{ return(_ns.match) }}
{% endmacro %}
