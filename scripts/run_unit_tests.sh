#!/usr/bin/env bash
# Runs the offline macro unit tests in unit_tests/. No Snowflake connection is used.
#
#   ./scripts/run_unit_tests.sh
#
# Works with whichever dbt is on PATH:
#   dbt v1 (dbt Core)  -> needs dbt-duckdb installed; compiles against in-memory DuckDB
#   dbt v2             -> compiles offline with placeholder Snowflake values
#
# Two passes:
#   1. `dbt compile` of every test model. A failed assertion is a compiler error.
#   2. One compile per line of unit_tests/expected_errors.txt, each of which must FAIL
#      with the listed message.
set -uo pipefail

cd "$(dirname "$0")/../unit_tests"
export DBT_SEND_ANONYMOUS_USAGE_STATS=false

version_line="$(dbt --version 2>&1 | grep -E -m1 '([0-9]+\.[0-9]+\.[0-9]+)')"
if echo "$version_line" | grep -q -E '(^|[^0-9.])2\.[0-9]+\.[0-9]+'; then
  engine="dbt v2"
  compile_args=(--profiles-dir . --target offline_snowflake --static-analysis off)
else
  engine="dbt v1"
  compile_args=(--profiles-dir . --target duckdb)
fi
echo "== Running macro unit tests on $engine ($version_line)"

dbt deps --profiles-dir . > /dev/null || { echo "dbt deps failed"; exit 1; }

echo "== Pass 1: assertions"
if ! output="$(dbt compile "${compile_args[@]}" 2>&1)"; then
  echo "$output"
  echo "FAILED: one or more unit test assertions failed"
  exit 1
fi
# Count the assertions that actually ran, so a test model that silently rendered nothing
# cannot pass unnoticed.
ok_count="$(grep -R -h -c -- '^-- ok: ' target/compiled 2>/dev/null | awk '{s+=$1} END {print s+0}')"
echo "   $ok_count assertions passed"
if [ "$ok_count" -lt 100 ]; then
  echo "FAILED: expected at least 100 assertions to run, found $ok_count"
  exit 1
fi

echo "== Pass 2: expected errors"
failures=0
while IFS='|' read -r case_name expected; do
  case "$case_name" in ''|\#*) continue ;; esac
  if output="$(dbt compile "${compile_args[@]}" --select test_expected_errors --vars "{expect_error: $case_name}" 2>&1)"; then
    echo "   FAIL $case_name: dbt succeeded but an error was expected"
    failures=$((failures + 1))
  elif ! echo "$output" | grep -q -F -- "$expected"; then
    echo "   FAIL $case_name: dbt failed, but not with: $expected"
    echo "$output" | tail -15
    failures=$((failures + 1))
  else
    echo "   ok   $case_name"
  fi
done < expected_errors.txt

if [ "$failures" -gt 0 ]; then
  echo "FAILED: $failures expected-error case(s) did not behave as expected"
  exit 1
fi
echo "== All macro unit tests passed on $engine"
