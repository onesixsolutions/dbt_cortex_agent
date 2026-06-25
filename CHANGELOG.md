# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `enable_versioning` config option — controls Snowflake Cortex Agent versioning; when `true` (default), uses `CREATE AGENT IF NOT EXISTS` + `ALTER AGENT MODIFY LIVE VERSION SET SPECIFICATION` instead of `CREATE OR REPLACE AGENT`, preserving version history across runs. `dbt run --full-refresh` falls back to `CREATE OR REPLACE`, resetting history. Set to `false` in dev environments to skip versioning overhead.
- `auto_commit` config option — when `enable_versioning=true`, automatically snapshot the LIVE version into a new immutable named version (`VERSION$1`, `VERSION$2`, …) after each run. Defaults to `true`. Set to `false` to accumulate spec changes in LIVE without committing, then commit manually via `ALTER AGENT COMMIT`.
- `version_comment` config option — optional comment string attached to the committed version snapshot; only used when `enable_versioning=true` and `auto_commit=true`.
- `snowflake__create_cortex_agent_if_not_exists` macro — `CREATE AGENT IF NOT EXISTS` DDL
- `snowflake__add_cortex_agent_live_version` macro — `ALTER AGENT ADD LIVE VERSION FROM LAST` DDL; recreates the LIVE working copy after `COMMIT` consumes it
- `snowflake__alter_cortex_agent_live_spec` macro — `ALTER AGENT MODIFY LIVE VERSION SET SPECIFICATION` DDL
- `snowflake__commit_cortex_agent_version` macro — `ALTER AGENT COMMIT` DDL
- `mcp_server` materialization for Snowflake-managed MCP servers — model body is the raw MCP server YAML specification (a `tools:` array), sent verbatim to `CREATE OR REPLACE MCP SERVER ... FROM SPECIFICATION`
- `snowflake__create_mcp_server` macro for DDL generation
- `snowflake__get_drop_mcp_server_sql` macro for DROP DDL generation
- Integration tests for the MCP server materialization (`mcp_server_test`), verified via `DESCRIBE MCP SERVER` captured into a table, since `GET_DDL` does not support MCP servers
- Local development setup: `integration_tests/.env` template, `scripts/run_tests.ps1` runner, and `profiles.yml` SSO support (`externalbrowser` authenticator)

### Changed
- `enable_versioning` now defaults to `true` — versioning is on by default for all `cortex_agent` models; set `enable_versioning: false` in `dbt_project.yml` or per-model config to opt out (e.g. in dev environments)

### Fixed
- Singular integration tests now declare `-- depends_on: {{ ref('cortex_agent_test') }}` so `dbt build` runs models before tests

## [0.4.2] - 2026-06-05

### Added
- `feedback_execute_as` config option — sets execution rights for the `AGENT_SUBMIT_FEEDBACK` procedure; accepts `'caller'` (default, captures end user via `current_user()`) or `'owner'` (use when the calling role lacks `INSERT` on the feedback table)

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
