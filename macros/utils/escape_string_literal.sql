-- Escapes a value for use inside a single-quoted SQL string literal by doubling apostrophes,
-- so that a comment such as  Don't use for forecasts  does not end the literal early and
-- break the statement.
--
-- A value that already contains an escaped apostrophe ('' or \') is returned unchanged:
-- before this macro existed the only way to get an apostrophe through was to escape it by
-- hand, and escaping those values again would corrupt them.
{% macro escape_string_literal(value) %}
  {%- set _text = value | string -%}
  {%- if "''" in _text or "\\'" in _text -%}
    {{ return(_text) }}
  {%- else -%}
    {{ return(_text | replace("'", "''")) }}
  {%- endif -%}
{% endmacro %}
