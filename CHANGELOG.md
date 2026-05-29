# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.1] - 2026-05-29

### Added
- `agent_grants` config option — list of role names to grant `USAGE` on the agent after creation (`grants` is reserved by dbt for its own privilege handling)
- `snowflake__grant_cortex_agent_usage` macro for GRANT DDL generation
- `create_feedback_table` config option — opt-in flag (default `false`) that creates an `AGENT_FEEDBACK` table and `AGENT_SUBMIT_FEEDBACK` stored procedure on each dbt run
- `feedback_schema` config option — overrides the schema (and optionally database) used for the feedback table and procedure; accepts `'SCHEMA'` or `'DB.SCHEMA'`
- `feedback_table` config option — fully-qualified override for the feedback table name
- `snowflake__create_feedback_table` macro for feedback table DDL generation
- `snowflake__create_feedback_procedure` macro for `AGENT_SUBMIT_FEEDBACK` stored procedure DDL generation; procedure records agent name, Snowflake current user, rating, optional comment, conversation history, and timestamp

### Changed
- Integration test suite consolidated to a single model (`cortex_agent_test`) covering all config and spec options, replacing the previous per-feature models (`cortex_agent_basic`, `cortex_agent_with_comment`, `cortex_agent_with_profile`)
- `AGENT_SUBMIT_FEEDBACK` tool description updated to require fresh rating and comment on each invocation — agents must not reuse or pre-fill values from prior feedback submissions; conversation history must exclude all previous feedback tool calls and their results

## [0.1.1] - 2026-05-21

### Fixed
- YAML specification indentation bug — first line of spec inherited 2-space indent from macro template, breaking YAML structure for any spec not starting with a blank line. Fixed by moving `{{ specification }}` to column 0 and adding `trim` filter.

## [0.1.0] - 2026-05-20

### Added
- `cortex_agent` materialization for Snowflake Cortex Agents
- Passthrough YAML specification — model body is sent verbatim to `CREATE OR REPLACE AGENT ... FROM SPECIFICATION`
- `comment` config option — sets agent-level description visible in Snowflake
- `profile` config option — JSON string for `display_name`, `avatar`, and `color`
- `snowflake__create_cortex_agent` macro for DDL generation
- `snowflake__get_drop_cortex_agent_sql` macro for DROP DDL generation
- Integration test suite under `integration_tests/`
- GitHub Actions CI workflow for automated integration testing
- `scripts/apply_license_headers.py` for Apache 2.0 header enforcement
