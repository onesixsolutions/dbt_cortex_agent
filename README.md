# dbt_cortex_agent

A custom dbt materialization for deploying [Snowflake Cortex Agents](https://docs.snowflake.com/en/sql-reference/sql/create-agent) using dbt. Define, version, and run Cortex Agents the same way you manage any other dbt model.

## Requirements

- dbt >= 1.0.0
- Snowflake adapter (`dbt-snowflake`)
- Snowflake account with Cortex Agents enabled
- Snowflake account with Cortex Search enabled (for `cortex_search_service` models)

## Installation

Add to your project's `packages.yml`:

```yaml
packages:
  - git: "https://github.com/onesixsolutions/dbt_cortex_agent"
    revision: "0.5.0"
```

Once this package is listed on the [dbt Package Hub](https://hub.getdbt.com/), you'll be able to install it via:

```yaml
packages:
  - package: onesixsolutions/dbt_cortex_agent
    version: [">=0.5.0", "<0.6.0"]
```

Then run:

```bash
dbt deps
```

## Usage

Create a model file whose **body is the raw Snowflake agent YAML specification**. The materialization wraps it in `CREATE OR REPLACE AGENT ... FROM SPECIFICATION $$ ... $$`.

```sql
-- models/agents/revenue_assistant.sql
{{ config(
    materialized='cortex_agent',
    comment='Revenue analysis assistant powered by Cortex Analyst',
    profile='{"display_name": "Revenue Assistant", "color": "blue"}'
) }}

models:
  orchestration: auto
orchestration:
  budget:
    seconds: 30
    tokens: 16000
instructions:
  response: 'You are a helpful revenue analyst. Answer questions using the available data.'
  sample_questions:
    - question: 'What was total revenue last quarter?'
    - question: 'Which clients had the highest chargeback rate?'
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: revenue_analyst
tool_resources:
  revenue_analyst:
    execution_environment:
      type: "warehouse"
      warehouse: "DBT_WH"
    semantic_view: '{{ ref("revenue_semantic_view") }}'
```

Run it:

```bash
dbt run --select revenue_assistant
```

Verify in Snowflake:

```sql
SHOW AGENTS IN SCHEMA my_db.my_schema;
```

## Config Options

| Option | Type | Required | Description |
|---|---|---|---|
| `materialized` | string | Yes | Must be `'cortex_agent'` |
| `comment` | string | No | Agent description visible in Snowflake |
| `profile` | string (JSON) | No | `{"display_name": "...", "avatar": "...", "color": "..."}` |
| `agent_grants` | list | No | Role names to grant `USAGE` on the agent, e.g. `['my_role']` |
| `create_feedback_table` | bool | No | Whether to create the feedback table and procedure. Defaults to `false`. Set to `true` to enable. See [Feedback Tool](#feedback-tool). |
| `feedback_schema` | string | No | Schema for the feedback table and `AGENT_SUBMIT_FEEDBACK` procedure. Accepts `'SCHEMA'` or `'DB.SCHEMA'`. Defaults to the agent's own database and schema. See [Feedback Tool](#feedback-tool). |
| `feedback_table` | string | No | Fully-qualified table name override for user feedback. Defaults to `{feedback_schema}.AGENT_FEEDBACK`. Ignored when `create_feedback_table` is `false`. See [Feedback Tool](#feedback-tool). |
| `feedback_execute_as` | string | No | Execution rights for the `AGENT_SUBMIT_FEEDBACK` procedure. `'caller'` (default) captures the end user via `current_user()`. Use `'owner'` if the calling role lacks `INSERT` on the feedback table. See [Feedback Tool](#feedback-tool). |
| `enable_versioning` | bool | No | Whether to use Snowflake agent versioning. Defaults to `true`. When `true`, uses `CREATE AGENT IF NOT EXISTS` + `ALTER AGENT MODIFY LIVE VERSION` instead of `CREATE OR REPLACE AGENT`, preserving version history across runs. Set to `false` in dev environments to skip versioning overhead. `dbt run --full-refresh` always falls back to `CREATE OR REPLACE`, resetting history. |
| `auto_commit` | bool | No | When `enable_versioning=true`, automatically snapshot the LIVE version into a new named version after each run. Defaults to `true`. Set to `false` to accumulate spec changes in LIVE without committing, then commit manually via `ALTER AGENT COMMIT`. |
| `version_comment` | string | No | Comment attached to each committed version snapshot. Only used when `enable_versioning=true` and `auto_commit=true`. |
| `set_default_version` | bool | No | Promote the newly committed version to DEFAULT so end users (and Snowsight's "In use") get it. Defaults to `true`. Only used when `enable_versioning=true` and `auto_commit=true`. `COMMIT` alone does not move the DEFAULT pointer — see [Version promotion](#version-promotion). |

## How It Works

The model body is passed verbatim as the agent YAML specification to Snowflake. Because it's a direct passthrough:

- All current and future Snowflake agent YAML options work automatically
- No package updates needed when Snowflake adds new features
- You can use Jinja (`{{ ref() }}`, `{{ var() }}`, etc.) anywhere in the spec
- `{{ ref() }}` calls in `tool_resources` resolve to fully qualified names **and** wire the agent into the dbt DAG — the agent will always run after its upstream semantic views

## Versioning

By default (`enable_versioning=true`, `auto_commit=true`) every `dbt run`:

1. Creates the agent if it doesn't exist (`CREATE AGENT IF NOT EXISTS`)
2. Restores a LIVE working copy from the last committed version (`ALTER AGENT ADD LIVE VERSION FROM LAST`), unless a LIVE copy already exists
3. Updates the LIVE copy with the latest compiled spec (`ALTER AGENT MODIFY LIVE VERSION SET SPECIFICATION`)
4. Commits the LIVE copy as a new named version — `VERSION$1`, `VERSION$2`, … (`ALTER AGENT COMMIT`)
5. Promotes that new version to DEFAULT (`ALTER AGENT SET DEFAULT_VERSION = 'LAST'`)

Version history accumulates across runs. `dbt run --full-refresh` falls back to `CREATE OR REPLACE AGENT`, resetting all history.

### Version promotion

Step 5 matters: **`COMMIT` alone does not move the DEFAULT pointer.** Snowflake treats the latest committed version as the default only *implicitly*, and that stops the moment `DEFAULT_VERSION` is set explicitly by anything out-of-band — most commonly Snowsight's **Publish** button. Once that happens the pointer is pinned, and every later `dbt run` commits a version that no user ever sees: Snowsight keeps showing an old version as "In use" while history piles up behind it.

Promoting explicitly on every commit makes deploys deterministic and self-healing — a pinned agent is un-stuck by the next `dbt run`. Opt out with `set_default_version=false` if you promote versions yourself (e.g. staged releases via aliases):

```sql
{{ config(materialized='cortex_agent', set_default_version=false) }}
```

Check which version is live:

```sql
SHOW VERSIONS IN AGENT my_db.my_schema.my_agent;  -- is_default = true marks the live one
```

> Note: `SET DEFAULT_VERSION` requires a **quoted** value — `'LAST'` or `'VERSION$3'`. The unquoted forms shown in some Snowflake docs (`LAST`, `VERSION$3`) fail with a SQL compilation error.

**Disable versioning in dev** to avoid the overhead when iterating quickly:

```yaml
# dbt_project.yml
models:
  my_project:
    agents:
      +enable_versioning: false
```

Or per-model:

```sql
{{ config(materialized='cortex_agent', enable_versioning=false) }}
```

**Commit manually** by setting `auto_commit=false` — the materialization keeps the LIVE version open across runs and you commit explicitly when ready:

```sql
{{ config(materialized='cortex_agent', auto_commit=false) }}
```

## Idempotency

With versioning enabled (default), every `dbt run` preserves history — re-runs are safe and create a new committed version. With `enable_versioning=false`, every run issues `CREATE OR REPLACE AGENT`. `dbt run --full-refresh` always uses `CREATE OR REPLACE AGENT`, resetting all version history.

## Supported Tools in Specification

Built-in tool types (add to the `tools:` section of your spec body):

- `cortex_analyst_text_to_sql` — text-to-SQL via a Cortex Analyst semantic model
- `cortex_search` — semantic search over unstructured content
- `generic` — any Snowflake stored procedure or UDF (see [Feedback Tool](#feedback-tool) for an example)

Refer to the [Snowflake CREATE AGENT docs](https://docs.snowflake.com/en/sql-reference/sql/create-agent) for the full and up-to-date YAML specification reference.

## Feedback Tool

All agents share a single feedback table and a single `AGENT_SUBMIT_FEEDBACK` procedure — no config required. On each `dbt run` the materialization provisions (idempotently):

1. A **feedback table** named `AGENT_FEEDBACK` in the agent's database and schema, with columns: `feedback_id`, `agent_name`, `user_name`, `rating`, `comment`, `conversation_history`, `created_at`
2. A **stored procedure** named `AGENT_SUBMIT_FEEDBACK` in the same location

By default both land in the agent's own schema. Use `feedback_schema` to place them in a shared schema instead:

```sql
{{ config(
    materialized='cortex_agent',
    feedback_schema='SHARED_SCHEMA'
) }}
```

Or with an explicit database:

```sql
{{ config(
    materialized='cortex_agent',
    feedback_schema='MY_DB.SHARED_SCHEMA'
) }}
```

To override the table name independently of the schema, use `feedback_table`:

```sql
{{ config(
    materialized='cortex_agent',
    feedback_schema='SHARED_SCHEMA',
    feedback_table='MY_DB.SHARED_SCHEMA.AGENT_FEEDBACK'
) }}
```

To enable feedback provisioning, set `create_feedback_table: true`:

```sql
{{ config(
    materialized='cortex_agent',
    create_feedback_table=true
) }}
```

Add the tool entry to your spec body so the agent can call it. Update the `identifier` to match your `feedback_schema` if you set one:

```sql
{{ config(
    materialized='cortex_agent',
    feedback_schema='SHARED_SCHEMA'
) }}

tools:
  - tool_spec:
      type: generic
      name: AGENT_SUBMIT_FEEDBACK
      description: 'Records user feedback about agent responses. Call when the user says "feedback" or explicitly rates or comments on a response. Each time feedback is triggered, ask the user fresh for a rating (1–5) and comment — do NOT reuse, reference, or pre-fill from any previously submitted feedback. For conversation_history, include only the last 10 messages that are NOT part of a prior feedback exchange (exclude all previous AGENT_SUBMIT_FEEDBACK tool calls and their results). Example: user says "1. Output wrong, expected $100" → call with rating=1, user_comment="Output wrong, expected $100". Example: user says "5. Completely Correct" → call with rating=5, user_comment="Completely Correct".'
      input_schema:
        type: object
        properties:
          agent_name:
            type: string
            description: 'Name of this agent. Always pass "{{ this.identifier | upper }}".'
          rating:
            type: number
            description: 'The user rating from 1 (worst) to 5 (best).'
          user_comment:
            type: string
            description: 'Optional free-text feedback.'
          conversation_history:
            type: string
            description: 'Last 10 messages from the conversation as a JSON string, e.g. [{"role":"user","content":"..."}].'
        required: [agent_name, rating, conversation_history]

tool_resources:
  AGENT_SUBMIT_FEEDBACK:
    execution_environment:
      query_timeout: 300
      type: warehouse
      warehouse: ''
    identifier: '{{ this.database }}.SHARED_SCHEMA.AGENT_SUBMIT_FEEDBACK'
    name: 'AGENT_SUBMIT_FEEDBACK(VARCHAR, NUMBER, VARCHAR, VARCHAR)'
    type: procedure
```

By default the procedure runs with `EXECUTE AS CALLER`, so `current_user()` inside the procedure captures the actual end user calling the agent. If the calling role does not have `INSERT` privileges on the feedback table, switch to owner rights:

```sql
{{ config(
    materialized='cortex_agent',
    create_feedback_table=true,
    feedback_execute_as='owner'
) }}
```

The procedure is recreated on every `dbt run`, so changes to the feedback table schema are picked up automatically. The feedback table uses `CREATE TABLE IF NOT EXISTS`, so existing data is never dropped.

## MCP Servers

The package also ships an `mcp_server` materialization for deploying [Snowflake-managed MCP servers](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-mcp). It works the same way as `cortex_agent`: the model body is the raw MCP server YAML specification (a `tools:` array), wrapped in `CREATE OR REPLACE MCP SERVER ... FROM SPECIFICATION $$ ... $$`.

```sql
-- models/mcp/data_mcp_server.sql
{{ config(materialized='mcp_server') }}

tools:
  - name: "product_search"
    type: "CORTEX_SEARCH_SERVICE_QUERY"
    identifier: "{{ ref('product_search_service') }}"
    title: "Product Search"
    description: "Cortex Search service over product documentation."

  - name: "revenue_analyst"
    type: "CORTEX_ANALYST_MESSAGE"
    identifier: "{{ ref('revenue_semantic_view') }}"
    title: "Revenue Analyst"
    description: "Semantic view for revenue analysis."

  - name: "sql_exec_tool"
    type: "SYSTEM_EXECUTE_SQL"
    title: "SQL Execution"
    description: "Execute read-only SQL against Snowflake."
    config:
      read_only: true
      query_timeout: 120
      warehouse: "MY_WAREHOUSE"
```

Run it:

```bash
dbt run --select data_mcp_server
```

Verify in Snowflake:

```sql
SHOW MCP SERVERS IN SCHEMA my_db.my_schema;
DESCRIBE MCP SERVER my_db.my_schema.data_mcp_server;
```

Notes specific to MCP servers:

- The `tools` array is required and must contain at least one tool. Supported `type` values include `CORTEX_SEARCH_SERVICE_QUERY`, `CORTEX_ANALYST_MESSAGE`, `CORTEX_AGENT_RUN`, `SYSTEM_EXECUTE_SQL`, and `GENERIC`. Each tool that wraps an existing object needs a fully-qualified `identifier` — use `{{ ref() }}` to wire it into the dbt DAG so the MCP server always runs after its upstream objects.
- Unlike agents, the MCP server DDL has **no `COMMENT` or `PROFILE` clause**, so the `mcp_server` materialization takes no extra config options — everything lives in the spec body.
- Like `cortex_agent`, every `dbt run` issues `CREATE OR REPLACE MCP SERVER`, so re-runs are fully idempotent, and Jinja (`{{ ref() }}`, `{{ var() }}`, etc.) works anywhere in the spec.
- To drop an MCP server explicitly, use the helper macro in a dbt operation or post-hook: `{% do run_query(dbt_cortex_agent.snowflake__get_drop_mcp_server_sql(this)) %}` (or run `DROP MCP SERVER IF EXISTS <db>.<schema>.<name>;` directly).

Refer to the [Snowflake CREATE MCP SERVER docs](https://docs.snowflake.com/en/sql-reference/sql/create-mcp-server) for the full and up-to-date specification reference.

## Cortex Search Services

The package also ships a `cortex_search_service` materialization for deploying [Snowflake Cortex Search Services](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-search/cortex-search-overview) — the backing search index used by a `cortex_search` tool on a Cortex Agent, or a `CORTEX_SEARCH_SERVICE_QUERY` tool on an MCP server.

Unlike `cortex_agent` and `mcp_server`, this materialization is **not** a YAML passthrough. The model body is a normal dbt `SELECT` query, which becomes the `AS <query>` clause of `CREATE CORTEX SEARCH SERVICE`. All other DDL clauses (search column, attributes, warehouse, target lag, etc.) come from `config()`.

Only the single-index syntax (`ON <search_column>` + `ATTRIBUTES`) is supported. If you need to search over multiple text fields, blend them into one column in the model's `SELECT` (e.g. `short_description || ' ' || long_description || ' ' || synonyms as search_text`) and keep the individual columns as `ATTRIBUTES` for filtering/display.

> `PRIMARY KEY` columns must be `TEXT` — Cortex Search Service rejects numeric types for `PRIMARY KEY` regardless of precision/scale, failing with `Invalid column type NUMBER(n,0) for source query column <col>`. Cast numeric ID columns to a string type, e.g. `id::varchar`, before using them in `primary_key`.

```sql
-- models/search/product_search.sql
{{ config(
    materialized='cortex_search_service',
    search_column='search_text',
    attributes=['id', 'title', 'category'],
    target_lag='1 hour',
    primary_key=['id'],
    comment='Product search index for the shopping assistant agent'
) }}

select
    id,
    title,
    category,
    short_description || ' ' || long_description || ' ' || synonyms as search_text
from {{ ref('products') }}
```

Run it:

```bash
dbt run --select product_search
```

Verify in Snowflake:

```sql
SHOW CORTEX SEARCH SERVICES IN SCHEMA my_db.my_schema;
DESCRIBE CORTEX SEARCH SERVICE my_db.my_schema.product_search;
```

### Config Options

| Option | Type | Required | Description |
|---|---|---|---|
| `materialized` | string | Yes | Must be `'cortex_search_service'` |
| `search_column` | string | Yes | Column that Cortex Search indexes and searches over. Immutable after creation — changing it requires `dbt run --full-refresh`. |
| `attributes` | list | Yes | Non-empty list of column names to index as filterable/returnable attributes. Snowflake requires at least one. |
| `target_lag` | string | Yes | Maximum staleness of the index relative to the source query, e.g. `'1 hour'`, `'7 days'`. No Snowflake default. |
| `warehouse` | string | No | Warehouse used to refresh and build the index. Defaults to the warehouse in your dbt `target`. |
| `primary_key` | list | No | Column(s) uniquely identifying each row; enables optimized incremental refresh. |
| `embedding_model` | string | No | Vector embedding model, e.g. `'snowflake-arctic-embed-m-v1.5'`. Immutable after creation. |
| `refresh_mode` | string | No | `INCREMENTAL` (default) or `FULL`. Immutable after creation. |
| `initialize` | string | No | `ON_CREATE` (default, synchronous) or `ON_SCHEDULE` (deferred). Immutable after creation. |
| `full_index_build_interval_days` | number | No | Soft target for periodic full index rebuilds. Only meaningful with `primary_key` set. |
| `request_logging` | bool | No | Enables request logging for monitoring queries. Defaults to `false`. |
| `auto_suspend` | number | No | Seconds of inactivity before suspending. Minimum `1800` (30 minutes). |
| `comment` | string | No | Descriptive text visible in Snowflake. |
| `search_service_grants` | list | No | Role names to grant `USAGE` on the search service, e.g. `['my_role']`. |

### How It Works

- **First run for a service, or `dbt run --full-refresh`:** issues `CREATE OR REPLACE CORTEX SEARCH SERVICE ... AS <query>` with the full set of configured options.
- **Every other run:** issues `ALTER CORTEX SEARCH SERVICE ... SET` to update only the mutable properties (`target_lag`, `warehouse`, `comment`, `auto_suspend`, `request_logging`, `full_index_build_interval_days`, `attributes`, `primary_key`) in place.

This split matters because `CREATE OR REPLACE` forces Snowflake to fully rebuild the search index from scratch. Unlike `mcp_server`, which issues `CREATE OR REPLACE` on every run because MCP server definitions are cheap to redefine, `cortex_search_service` avoids doing that on steady-state runs — recreating the service on every `dbt run` would discard Cortex Search's own incremental refresh and be wasteful and slow for anything beyond trivial data volumes.

`search_column`, `embedding_model`, `refresh_mode`, `initialize`, and the defining query itself are immutable once the service is created. To change any of those, run `dbt run --full-refresh`.

## Local Development

### Prerequisites

- PowerShell
- dbt-snowflake installed in your environment
- A Snowflake account with Cortex Agents enabled

### Setup

1. Copy the env template and fill in your Snowflake details:

```powershell
# integration_tests/.env is git-ignored
```

Edit `integration_tests/.env`:

```
SNOWFLAKE_TEST_ACCOUNT=<orgname>-<accountname>
SNOWFLAKE_TEST_USER=you@example.com
SNOWFLAKE_TEST_ROLE=<your_role>
SNOWFLAKE_TEST_DATABASE=<your_database>
SNOWFLAKE_TEST_WAREHOUSE=<your_warehouse>
SNOWFLAKE_TEST_SCHEMA=<your_schema>
SNOWFLAKE_TEST_AUTHENTICATOR=externalbrowser
```

> Set `SNOWFLAKE_TEST_AUTHENTICATOR=externalbrowser` for Google SSO (a browser window will open on first connection). For key-pair auth, set it to `snowflake_jwt` and add `SNOWFLAKE_TEST_PRIVATE_KEY_PATH` and `SNOWFLAKE_TEST_PRIVATE_KEY_PASSPHRASE`.

2. Run the integration tests:

```powershell
.\scripts\run_tests.ps1
```

This script stages a clean copy of the package to avoid a Windows path-length issue caused by dbt's recursive local package installation, then runs `dbt deps` and `dbt build` from `integration_tests/`.

> CI always runs against a freshly created schema, so it only ever exercises the `cortex_search_service` CREATE path. To verify the ALTER-in-place path, run `.\scripts\run_tests.ps1` twice in a row against the same persistent dev schema and confirm the second run issues `ALTER CORTEX SEARCH SERVICE ... SET` instead of another `CREATE OR REPLACE`.

To install packages only (no build):

```powershell
.\scripts\run_tests.ps1 -DepsOnly
```

## License

[Apache License 2.0](LICENSE)
