# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.0] - 2026-11-25

Makes agent versioning safe to run on a schedule and under `--full-refresh`.

**Upgrade notes — behaviour changes**
- **A run that does not change an agent's specification no longer commits a version.** Previously every run added one. Set `commit_only_on_change: false` for the old behaviour.
- **`dbt run --full-refresh` no longer replaces a versioned agent.** It used to issue `CREATE OR REPLACE AGENT`, deleting the agent's version history. To replace an agent on a full refresh, set `replace_on_full_refresh: true` on that model. Agents with `enable_versioning: false` are unaffected (they are replaced on every run, as before).
- `comment` and `profile` are now applied to existing versioned agents on every run. If you changed either in your project after an agent was created, that change will take effect on the next run.

### Added
- `commit_only_on_change` config option for `cortex_agent` (default `true`) — the compiled specification is compared with the deployed one, and the update and commit are skipped when they are the same
- `replace_on_full_refresh` config option for `cortex_agent` (default `false`)
- `summarize_agent_versions`, `agent_spec_matches`, `snowflake__alter_cortex_agent_properties` and `assert_no_dollar_quote` macros
- CI runs the versioned agents a third time with `--full-refresh` and checks their history survives

### Changed
- The versioned path no longer runs `SHOW AGENTS` to check whether the agent exists; it creates the agent if needed and then reads `SHOW VERSIONS IN AGENT`

### Fixed
- A new agent version was committed on every run, whether or not the specification had changed, so a scheduled job filled the version history with identical versions
- `dbt run --full-refresh` — routinely run across a whole project — replaced every versioned agent in it, deleting their version history
- `comment` and `profile` were only applied when a versioned agent was first created; later edits were silently ignored. They are now applied with `ALTER AGENT ... SET` on every run
- A model body containing `$$` ended the dollar-quoted string it is sent in and produced an unrelated-looking Snowflake syntax error. It now fails at compile time with a message naming the model

## [1.1.0] - 2026-11-25

Adds dbt v2 support, fixes several ways grants were lost or never issued, and adds an offline unit test suite. Existing dbt v1 projects need no changes.

**Upgrade notes**
- Moving to dbt v2: put package options under `meta` (see README "dbt v2"). Top-level keys still work on dbt v1.
- `CREATE OR REPLACE AGENT` now includes `COPY GRANTS`. If you relied on a replace clearing an agent's grants, set `copy_grants: false`.
- `snowflake__grant_cortex_agent_usage`, `snowflake__grant_cortex_search_service_usage` and `snowflake__alter_cortex_search_service` return a list of statements instead of one string. This only matters if your project calls them directly.

### Added
- dbt v2 support. The dbt v2 engine rejects config keys it does not know (`Ignored unexpected key`, dbt1060), which made every model using a package option fail to parse. All package options can now be set under `meta` — e.g. `config(materialized='cortex_agent', meta={'comment': '...', 'agent_grants': [...]})` — which works on dbt v1 and v2. Top-level keys keep working on dbt v1, so existing projects are unaffected until they upgrade. When an option is set in both places the `meta` value wins.
- `get_package_config` macro — reads a package option from `meta`, falling back to the top-level config key
- CI now runs the integration tests on both dbt v1 (`dbt-snowflake`) and dbt v2 (`dbt`)
- Offline macro unit tests in `unit_tests/`, run with `scripts/run_unit_tests.sh` on dbt v1 and v2 without a Snowflake connection, and in CI on every pull request
- Integration tests for grants on agents, MCP servers, search services and the feedback procedure; for `revoke_unlisted_grants`; for `COPY GRANTS` across a replace; for the search service ALTER path; and for version increments on a second run
- CI runs the integration models twice (the second time with `--vars '{second_run: true}'`) so the ALTER, second-version and `COPY GRANTS` paths are exercised

- `mcp_server_grants` config option for `mcp_server` — list of role names to grant `USAGE` on the MCP server, re-issued after every run
- `snowflake__grant_mcp_server_usage` macro
- `copy_grants` config option for `cortex_agent` (default `true`) — adds `COPY GRANTS` to `CREATE OR REPLACE AGENT`
- `snowflake__grant_feedback_procedure_usage` macro
- `agent_grants`, `search_service_grants` and `mcp_server_grants` now also accept a map of privilege to roles (e.g. `{'usage': ['analyst_role'], 'monitor': ['ops_role']}`), so privileges other than `USAGE` — `MONITOR`, `MODIFY`, `OPERATE` — can be managed. The list form still grants `USAGE`.
- Database roles as grantees: prefix the name with `database role `, e.g. `'database role ANALYTICS.AGENT_READER'`
- `revoke_unlisted_grants` config option for `cortex_agent` and `cortex_search_service` (default `false`) — revokes privileges held by account roles that the grants option does not list, making it the full definition of access instead of an additive list
- `normalize_grants`, `grantee_clause`, `get_grant_statements`, `get_revoke_unlisted_grant_statements` and `get_revoke_statements_for_rows` macros

### Changed
- Package options are read with `config.meta_get()`, dbt's recommended accessor for custom keys, where it exists (dbt Core 1.10+ and dbt v2), falling back to the `meta` dictionary on older versions
- A model that sets dbt's native `grants` config now gets a warning: these materializations do not apply it, and it previously did nothing silently
- The integration test agent names its Cortex Search Service with the documented `search_service` key instead of `name`
- `CREATE OR REPLACE AGENT` (used when `enable_versioning: false` and on `--full-refresh`) now includes `COPY GRANTS`, so privileges granted on the agent outside of `agent_grants` are no longer dropped on each replace. Set `copy_grants: false` for the previous behaviour.
- `AGENT_SUBMIT_FEEDBACK` is now replaced with `COPY GRANTS`, so grants on the shared procedure survive each run
- `snowflake__grant_cortex_agent_usage`, `snowflake__grant_cortex_search_service_usage` and `snowflake__alter_cortex_search_service` now return a **list of SQL statements** instead of one `;`-separated string, and the materializations execute each statement on its own. Sending several statements in one call relied on dbt-snowflake's client-side statement splitting, which is not guaranteed on the dbt v2 engine. Only affects projects that call these macros directly.
- README examples and the integration tests set package options under `meta`

### Documentation
- New "Design Notes and Limitations" section listing where these materializations differ from dbt's built-in ones
- README reviewed against the current Snowflake documentation: new [Required Privileges](README.md#required-privileges) section covering what the deploying role and consuming roles need beyond the object grant; a section for the previously undocumented `cortex_agent_evaluation` materialization, including the `dataset`-block re-run caveat, `agent_version`, metric version pinning and the privileges needed to start a run; current MCP server tool types (`CODING_AGENT`, `tool_config`, `annotations`); current agent tool types and the `tool_not_accessible` setting; and a note on Snowflake's native feedback endpoint

### Fixed
- An apostrophe in `comment`, `profile` or `version_comment` ended the SQL string literal early and failed the statement. Apostrophes are now escaped (`escape_string_literal` macro). Values that already contain a hand-escaped apostrophe (`''` or `\'`) are left as they are.
- Existence checks for agents and search services could match the wrong object. `SHOW ... LIKE '<name>'` treats `_` as a single-character wildcard, so e.g. `SALES_AGENT` also matched `SALESXAGENT`, sending the materialization down the ALTER path for an object that did not exist. The returned name is now compared exactly (`find_show_row` macro).
- `cortex_search_service` now warns when `search_column` or `embedding_model` in the model config no longer matches the deployed service. These are fixed at creation and were silently ignored on the ALTER path.
- Agent LIVE-version detection also recognises a `SHOW VERSIONS` row named `LIVE`, not only a row with an empty name
- MCP servers lost every grant on each `dbt run`: the server is always replaced, replacing drops all grants, and the materialization had no way to re-issue them. Use `mcp_server_grants`.
- Roles in `agent_grants` could not call the feedback tool: they were granted `USAGE` on the agent but never on the `AGENT_SUBMIT_FEEDBACK` procedure behind it. They are now granted both.
- `UnexpectedJinjaBlockDeprecation` warning on dbt Core 1.10+ caused by a `do` tag inside a SQL comment in `drop_mcp_server.sql`

## [1.0.0] - 2026-08-12

Declares the package's API stable, per Semantic Versioning's guidance for production-ready releases. No functional changes from `0.5.0`.

## [0.5.0] - 2026-08-12

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
- `cortex_search_service` materialization for [Snowflake Cortex Search Services](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-search/cortex-search-overview) — unlike `cortex_agent`/`mcp_server`, the model body is a normal dbt `SELECT` query (not a passthrough YAML spec) that becomes the `AS <query>` clause; supports the single-index (`ON` + `ATTRIBUTES`) syntax only
- `search_column`, `attributes`, and `target_lag` required config options for `cortex_search_service` — Snowflake has no default for any of these
- `warehouse`, `primary_key`, `embedding_model`, `refresh_mode`, `initialize`, `full_index_build_interval_days`, `request_logging`, `auto_suspend`, and `comment` optional config options for `cortex_search_service`
- `search_service_grants` config option — list of role names to grant `USAGE` on the search service after creation, mirrors `agent_grants`
- Refresh behavior: `cortex_search_service` issues `CREATE OR REPLACE CORTEX SEARCH SERVICE` only on the first run for a given service or on `dbt run --full-refresh`; subsequent runs use `ALTER CORTEX SEARCH SERVICE ... SET` to update mutable properties in place, avoiding a full index rebuild on every `dbt run`
- `snowflake__create_cortex_search_service` macro for CREATE DDL generation
- `snowflake__alter_cortex_search_service` macro for ALTER ... SET DDL generation — emits one `ALTER CORTEX SEARCH SERVICE ... SET <property> = <value>;` statement per scalar mutable property (target_lag, warehouse, comment, auto_suspend, request_logging, full_index_build_interval_days) rather than combining them into a single `SET` clause, since Snowflake rejected a combined multi-property `SET` clause with a syntax error; `primary_key` and `attributes` each use their own dedicated `SET PRIMARY KEY = (...)` / `SET ATTRIBUTES (...)` statement forms per Snowflake's syntax reference
- `snowflake__get_drop_cortex_search_service_sql` macro for DROP DDL generation
- `snowflake__grant_cortex_search_service_usage` macro for GRANT DDL generation
- Integration tests for the Cortex Search Service materialization (`test_search_service`), verified via `DESCRIBE CORTEX SEARCH SERVICE` captured into a table, since `GET_DDL` support for search services is not documented

### Changed
- `enable_versioning` now defaults to `true` — versioning is on by default for all `cortex_agent` models; set `enable_versioning: false` in `dbt_project.yml` or per-model config to opt out (e.g. in dev environments)
- `base_table` integration test model no longer creates `TEST_SEARCH_SERVICE` via a raw-SQL `post_hook`; it's now a separate `test_search_service` model using the `cortex_search_service` materialization

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
