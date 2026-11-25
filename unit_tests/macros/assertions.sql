-- Assertion helpers for the offline unit tests. A failed assertion raises a compiler error,
-- which fails `dbt compile`; a passing one renders a SQL comment naming the test.

-- Collapses all runs of whitespace to single spaces, so multi-line DDL can be compared
-- without the test depending on indentation.
{% macro normalize_sql(text) %}
  {{ return((text | string).split() | join(' ')) }}
{% endmacro %}

{% macro assert_equal(name, actual, expected) %}
  {%- if actual != expected -%}
    {{ exceptions.raise_compiler_error("UNIT TEST FAILED: " ~ name ~ "\n  expected: " ~ (expected | string) ~ "\n  actual:   " ~ (actual | string)) }}
  {%- endif %}
-- ok: {{ name }}
{% endmacro %}

-- Compares SQL text ignoring whitespace differences.
{% macro assert_sql(name, actual, expected) %}
  {{- assert_equal(name, normalize_sql(actual), normalize_sql(expected)) -}}
{% endmacro %}

{% macro assert_true(name, condition) %}
  {%- if not condition -%}
    {{ exceptions.raise_compiler_error("UNIT TEST FAILED: " ~ name ~ " (expected a true condition)") }}
  {%- endif %}
-- ok: {{ name }}
{% endmacro %}

{% macro assert_contains(name, haystack, needle) %}
  {%- if needle not in (haystack | string) -%}
    {{ exceptions.raise_compiler_error("UNIT TEST FAILED: " ~ name ~ "\n  expected to find: " ~ needle ~ "\n  in:               " ~ (haystack | string)) }}
  {%- endif %}
-- ok: {{ name }}
{% endmacro %}

{% macro assert_not_contains(name, haystack, needle) %}
  {%- if needle in (haystack | string) -%}
    {{ exceptions.raise_compiler_error("UNIT TEST FAILED: " ~ name ~ "\n  expected NOT to find: " ~ needle ~ "\n  in:                   " ~ (haystack | string)) }}
  {%- endif %}
-- ok: {{ name }}
{% endmacro %}

-- The relation every DDL test targets.
{% macro test_relation(identifier='OBJ') %}
  {{ return(api.Relation.create(database='DB', schema='SCH', identifier=identifier, type='view')) }}
{% endmacro %}
