# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `grants` config option — list of role names to grant `USAGE` on the agent after creation
- `snowflake__grant_cortex_agent_usage` macro for GRANT DDL generation

### Changed
- Integration test suite consolidated to a single model (`cortex_agent_test`) covering all config and spec options, replacing the previous per-feature models (`cortex_agent_basic`, `cortex_agent_with_comment`, `cortex_agent_with_profile`)

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
