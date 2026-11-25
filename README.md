# dbt_cortex_agent

Custom dbt materializations for deploying [Snowflake Cortex Agents](https://docs.snowflake.com/en/sql-reference/sql/create-agent) and the objects around them with dbt. Define, version, grant and test them the same way you manage any other dbt model.

| Materialization | Deploys | Model body |
|---|---|---|
| [`cortex_agent`](#usage) | A Cortex Agent, with Snowflake agent versioning | Agent YAML specification |
| [`mcp_server`](#mcp-servers) | A Snowflake-managed MCP server | MCP server YAML specification |
| [`cortex_search_service`](#cortex-search-services) | A Cortex Search Service | `SELECT` query |
| [`cortex_agent_evaluation`](#agent-evaluations) | A Cortex Agent evaluation run configuration | Evaluation YAML |

Works on dbt v1 and dbt v2.

## Requirements

- dbt v1 (dbt Core >= 1.0.0 with the `dbt-snowflake` adapter) or dbt v2 — see [dbt v2](#dbt-v2) for how config options are set there
- Snowflake account with Cortex Agents enabled
- Snowflake account with Cortex Search enabled (for `cortex_search_service` models)

## Installation

Add to your project's `packages.yml`:

```yaml
packages:
  - git: "https://github.com/onesixsolutions/dbt_cortex_agent"
    revision: "1.2.0"
```

Once this package is listed on the [dbt Package Hub](https://hub.getdbt.com/), you'll be able to install it via:

```yaml
packages:
  - package: onesixsolutions/dbt_cortex_agent
    version: [">=1.0.0", "<2.0.0"]
```

Then run:

```bash
dbt deps
```

## Usage

Create a model file whose **body is the raw Snowflake agent YAML specification**. The materialization passes it to Snowflake as the agent's `FROM SPECIFICATION $$ ... $$` — creating the agent on the first run and committing a new version of it on later runs (see [Versioning](#versioning)).

```sql
-- models/agents/revenue_assistant.sql
{{ config(
    materialized='cortex_agent',
    meta={
        'comment': 'Revenue analysis assistant powered by Cortex Analyst',
        'profile': '{"display_name": "Revenue Assistant", "color": "blue"}'
    }
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

Every option below except `materialized` is a package option: set it under `meta` (recommended — works on every dbt version) or, on dbt v1 only, as a top-level config key. See [dbt v2](#dbt-v2).

| Option | Type | Required | Description |
|---|---|---|---|
| `materialized` | string | Yes | Must be `'cortex_agent'` |
| `comment` | string | No | Agent description visible in Snowflake. Applied on every run, and to all versions at once — it belongs to the agent, not to a version. |
| `profile` | string (JSON) | No | `{"display_name": "...", "avatar": "...", "color": "..."}`. Applied on every run, and to all versions at once. |
| `agent_grants` | list or map | No | Who gets access to the agent. A list of role names grants `USAGE` to each, e.g. `['my_role']`; a map grants any agent privilege, e.g. `{'usage': ['my_role'], 'monitor': ['ops_role']}`. See [Grants](#grants). With `create_feedback_table: true` the `USAGE` grantees also get `USAGE` on the `AGENT_SUBMIT_FEEDBACK` procedure. |
| `revoke_unlisted_grants` | bool | No | Revoke privileges held on the agent by account roles that `agent_grants` does not list. Defaults to `false`. See [Grants](#grants). |
| `copy_grants` | bool | No | Add `COPY GRANTS` to `CREATE OR REPLACE AGENT` so privileges granted on the agent outside of dbt survive a replace. Defaults to `true`. Only relevant when the agent is replaced — `enable_versioning: false`, or `--full-refresh` with `replace_on_full_refresh: true`. |
| `create_feedback_table` | bool | No | Whether to create the feedback table and procedure. Defaults to `false`. Set to `true` to enable. See [Feedback Tool](#feedback-tool). |
| `feedback_schema` | string | No | Schema for the feedback table and `AGENT_SUBMIT_FEEDBACK` procedure. Accepts `'SCHEMA'` or `'DB.SCHEMA'`. Defaults to the agent's own database and schema. See [Feedback Tool](#feedback-tool). |
| `feedback_table` | string | No | Fully-qualified table name override for user feedback. Defaults to `{feedback_schema}.AGENT_FEEDBACK`. Ignored when `create_feedback_table` is `false`. See [Feedback Tool](#feedback-tool). |
| `feedback_execute_as` | string | No | Execution rights for the `AGENT_SUBMIT_FEEDBACK` procedure. `'caller'` (default) captures the end user via `current_user()`. Use `'owner'` if the calling role lacks `INSERT` on the feedback table. See [Feedback Tool](#feedback-tool). |
| `enable_versioning` | bool | No | Whether to use Snowflake agent versioning. Defaults to `true`. When `true`, the agent is created once and later runs update it through `ALTER AGENT`, preserving version history. When `false`, every run issues `CREATE OR REPLACE AGENT` — useful in dev, but it resets the agent each time. See [Versioning](#versioning). |
| `commit_only_on_change` | bool | No | Compare the compiled specification with the deployed one and skip the update and commit when they are the same, so a run that changes nothing adds no version. Defaults to `true`. Set to `false` to commit a version on every run. |
| `replace_on_full_refresh` | bool | No | Let `dbt run --full-refresh` replace a versioned agent with `CREATE OR REPLACE AGENT`, **deleting its version history**. Defaults to `false`: a full refresh deploys a versioned agent like any other run. See [Full refresh](#full-refresh). |
| `auto_commit` | bool | No | When `enable_versioning=true`, snapshot the LIVE version into a new named version after a run that changed the specification. Defaults to `true`. Set to `false` to accumulate spec changes in LIVE without committing, then commit manually via `ALTER AGENT COMMIT`. |
| `version_comment` | string | No | Comment attached to each committed version snapshot. Only used when `enable_versioning=true` and `auto_commit=true`. |
| `set_default_version` | bool | No | Promote the newly committed version to DEFAULT so end users (and Snowsight's "In use") get it. Defaults to `true`. Only used when `enable_versioning=true` and `auto_commit=true`. `COMMIT` alone does not move the DEFAULT pointer — see [Version promotion](#version-promotion). |

## Grants

`agent_grants`, `search_service_grants` and `mcp_server_grants` all accept the same two forms.

A **list** grants `USAGE` to each role:

```sql
{{ config(materialized='cortex_agent', meta={'agent_grants': ['analyst_role', 'support_role']}) }}
```

A **map of privilege to roles**, like dbt's native `grants` config, grants any privilege the object type supports:

```sql
{{ config(
    materialized='cortex_agent',
    meta={'agent_grants': {'usage': ['analyst_role'], 'monitor': ['ops_role']}}
) }}
```

| Object | Privileges |
|---|---|
| Agent | `usage` (run the agent), `monitor` (view threads, logs and traces; needed to run and read evaluations), `modify` (alter or drop) |
| Cortex Search Service | `usage` (query), `monitor` (view refresh history), `operate` (suspend/resume, refresh, change warehouse and target lag) |
| MCP server | `usage` (connect, list and call tools), `modify` (describe or drop) |

`OWNERSHIP` cannot be granted through these options.

A grantee is an account role unless you prefix it with `database role `:

```yaml
agent_grants:
  usage: ['analyst_role', 'database role ANALYTICS.AGENT_READER']
```

### Revoking

By default grants are **additive**: the materialization grants what is listed and never revokes anything, so removing a role from the list leaves its access in place. Set `revoke_unlisted_grants: true` on an agent or search service to make the list the full definition of access — after each run, any privilege held by an account role that is not listed is revoked.

- Only grants to account roles are revoked. Grants to database roles, shares and application roles are left alone, and `OWNERSHIP` is never touched.
- Snowflake only lets a role revoke grants that it (or a role below it) made, unless it holds `MANAGE GRANTS`. A grant made by an unrelated role makes the `REVOKE` — and so the model — fail.
- MCP servers have no such option: they are replaced on every run, which already drops every grant not in `mcp_server_grants`.

## dbt v2

The dbt v2 engine validates config keys strictly: a key it does not recognise at the top level of `config()`, `schema.yml` or `dbt_project.yml` fails parsing with `Ignored unexpected key` (dbt1060). Package options such as `comment`, `agent_grants` or `search_column` are not native dbt configs, so on dbt v2 they must go under `meta`, which is dbt's supported home for custom keys:

```sql
{{ config(
    materialized='cortex_agent',
    meta={'comment': 'Revenue assistant', 'agent_grants': ['analyst_role']}
) }}
```

```yaml
# schema.yml / properties file
models:
  - name: revenue_assistant
    config:
      meta:
        comment: Revenue assistant
        agent_grants: ['analyst_role']
```

Every materialization in this package reads each option from `meta` first and falls back to the top-level key, so:

- **`meta` works on dbt v1 and dbt v2.** All examples in this README use it.
- **Top-level keys (`config(comment='...')`) still work on dbt v1**, so existing projects keep running unchanged. Move them under `meta` before upgrading to dbt v2.
- If an option is set in both places, the `meta` value wins.

dbt merges `meta` across `dbt_project.yml`, properties files and `config()` blocks, so project-level defaults still combine with per-model settings.

On dbt v2 the YAML-bodied models (`cortex_agent`, `mcp_server`, `cortex_agent_evaluation`) produce `SyntaxInvalid` static-analysis *warnings*, because their bodies are specifications rather than SQL. These are harmless; set `static_analysis: off` on those models to silence them.

## How It Works

The model body is passed verbatim as the agent YAML specification to Snowflake. Because it's a direct passthrough:

- All current and future Snowflake agent YAML options work automatically
- No package updates needed when Snowflake adds new features
- You can use Jinja (`{{ ref() }}`, `{{ var() }}`, etc.) anywhere in the spec
- `{{ ref() }}` calls in `tool_resources` resolve to fully qualified names **and** wire the agent into the dbt DAG — the agent will always run after its upstream semantic views

## Versioning

By default (`enable_versioning=true`, `auto_commit=true`) every `dbt run`:

1. Creates the agent if it doesn't exist (`CREATE AGENT IF NOT EXISTS`)
2. Applies `comment` and `profile`, if set (`ALTER AGENT ... SET`). These belong to the agent rather than to a version, so they take effect immediately for every version.
3. Compares the compiled specification with the newest committed version. **If they are the same, it stops here** — no version is added.
4. Otherwise restores a LIVE working copy from the last committed version (`ALTER AGENT ADD LIVE VERSION FROM LAST`), unless one already exists
5. Updates the LIVE copy with the compiled spec (`ALTER AGENT MODIFY LIVE VERSION SET SPECIFICATION`)
6. Commits the LIVE copy as a new named version — `VERSION$2`, `VERSION$3`, … (`ALTER AGENT COMMIT`)
7. Promotes the newest version to DEFAULT (`ALTER AGENT SET DEFAULT_VERSION = 'LAST'`). This runs whether or not a version was added.

So the version history records each change to the specification once, and a scheduled job that runs the agent model without changing it leaves the history alone.

### Change detection

Step 3 parses both the model body and the specification Snowflake returns (`SHOW VERSIONS IN AGENT`) and compares them as data, so formatting, comments and key order don't count as changes. The comparison is exact and errs on the side of deploying: if the two can't be shown to be identical, the run proceeds as if the spec had changed. The worst outcome of a mismatch is one redundant version, never a skipped deploy.

Things that are **not** part of the specification, and so never create a version on their own: `comment`, `profile`, `version_comment`, and grants.

With `auto_commit=false` the comparison is against the LIVE working copy instead, since that is what such a run updates.

To go back to committing a version on every run, set `commit_only_on_change: false`.

### Full refresh

`dbt run --full-refresh` does **not** replace a versioned agent. `CREATE OR REPLACE AGENT` resets an agent to `VERSION$1`, permanently deleting its version history, and `--full-refresh` is commonly run across a whole project to rebuild incremental models — which would silently wipe every agent in it. A full refresh therefore deploys a versioned agent exactly like a normal run, and says so in the log.

To deliberately replace an agent and start its history over, opt in on that model and run it with `--full-refresh`:

```sql
{{ config(materialized='cortex_agent', meta={'replace_on_full_refresh': true}) }}
```

### Version promotion

Step 5 matters: **`COMMIT` alone does not move the DEFAULT pointer.** Snowflake treats the latest committed version as the default only *implicitly*, and that stops the moment `DEFAULT_VERSION` is set explicitly by anything out-of-band — most commonly Snowsight's **Publish** button. Once that happens the pointer is pinned, and every later `dbt run` commits a version that no user ever sees: Snowsight keeps showing an old version as "In use" while history piles up behind it.

Promoting explicitly on every commit makes deploys deterministic and self-healing — a pinned agent is un-stuck by the next `dbt run`. Opt out with `set_default_version=false` if you promote versions yourself (e.g. staged releases via aliases):

```sql
{{ config(materialized='cortex_agent', meta={'set_default_version': false}) }}
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
      +meta:
        enable_versioning: false
```

Or per-model:

```sql
{{ config(materialized='cortex_agent', meta={'enable_versioning': false}) }}
```

**Commit manually** by setting `auto_commit=false` — the materialization keeps the LIVE version open across runs and you commit explicitly when ready:

```sql
{{ config(materialized='cortex_agent', meta={'auto_commit': false}) }}
```

Only the agent is versioned. Semantic views, search services and procedures that the agent's tools use are shared by every version, including the one end users are on — changing one of those changes behaviour for all versions at once, and rolling an agent back to an earlier version does not roll them back.

## Idempotency

With versioning enabled (default), re-running an unchanged agent is a no-op for its version history, and running a changed one adds exactly one version. With `enable_versioning=false`, every run issues `CREATE OR REPLACE AGENT`. A versioned agent is only replaced by `--full-refresh` together with `replace_on_full_refresh: true`.

Replacing an agent would normally drop every privilege granted on it. The materialization adds `COPY GRANTS` to `CREATE OR REPLACE AGENT`, so existing grants (other than `OWNERSHIP`) carry over. Set `copy_grants: false` to get a clean slate on each replace, leaving only the roles in `agent_grants`.

## Design Notes and Limitations

These materializations deploy object types dbt has no built-in concept of, so a few things differ from a table or view model:

- **Relation type.** dbt needs every model to be a table or view in its relation cache, so each object is registered as a `view` placeholder. No view is ever created. One consequence: if you later change a model *away* from one of these materializations, dbt will try to drop a view of that name, which does nothing to the agent, server or service — drop it yourself first.
- **dbt's native `grants` config is not applied.** dbt's built-in grant handling only knows tables and views. Use `agent_grants`, `search_service_grants` or `mcp_server_grants` instead (see [Grants](#grants)); a model that sets the native `grants` config gets a warning.
- **`persist_docs` is not applied.** Use the `comment` option to describe an agent or search service in Snowflake.
- **Object names are used unquoted**, as `database.schema.identifier`. Names that need quoting (mixed case, special characters) are not supported.
- **String options are placed in single-quoted SQL literals.** Apostrophes in `comment`, `profile` and `version_comment` are escaped for you. The YAML body is placed in a `$$ ... $$` block, so it must not itself contain `$$`; a body that does fails at compile time with a message naming the model.
- **Snowflake does not validate a specification's tools when the object is created.** A misspelled key or a reference to a missing object deploys successfully and only shows up when the tool is used — test the agent after deploying it.
- **Models sharing a feedback schema share one `AGENT_SUBMIT_FEEDBACK` procedure**, which each of them replaces on every run.

## Supported Tools in Specification

Built-in tool types (add to the `tools:` section of your spec body):

- `cortex_analyst_text_to_sql` — text-to-SQL via a Cortex Analyst semantic view or semantic model
- `cortex_search` — semantic search over unstructured content
- `generic` — any Snowflake stored procedure or UDF (see [Feedback Tool](#feedback-tool) for an example)
- `web_search` — web search (must be enabled for the account by an `ACCOUNTADMIN`)
- `data_to_chart` — chart generation (available by default)

In `tool_resources`, the entry for a `cortex_search` tool names its service with the `search_service` key:

```yaml
tool_resources:
  product_search:
    search_service: '{{ ref("product_search_service") }}'
    max_results: 10
```

MCP connectors are configured through the top-level `mcp_servers` key of the spec. Because the body is a passthrough, anything else Snowflake adds to the specification works without a package change.

Refer to the [Snowflake CREATE AGENT docs](https://docs.snowflake.com/en/sql-reference/sql/create-agent) for the full and up-to-date YAML specification reference.

### Tools the caller cannot access

A role needs its own privileges on every object an agent's tools use (see [Required Privileges](#required-privileges)). By default Snowflake does **not** fail a run when the caller lacks one: the tool is skipped and the agent answers without it, which looks like a worse answer rather than an error. To make a missing privilege fail loudly, set this in the spec body:

```yaml
orchestration:
  tool_not_accessible: reject
```

## Required Privileges

Summarised from the Snowflake documentation; check it for the authoritative list.

### The role running dbt

| To deploy | The role needs |
|---|---|
| Any object | `USAGE` on the database and schema, and to **own** the object on later runs — replacing an agent, MCP server or search service requires `OWNERSHIP` |
| `cortex_agent` | `CREATE AGENT` on the schema |
| `mcp_server` | `CREATE MCP SERVER` on the schema |
| `cortex_search_service` | `CREATE CORTEX SEARCH SERVICE` on the schema, `SELECT` on the tables the query reads, `USAGE` on the warehouse, and the `SNOWFLAKE.CORTEX_USER` or `SNOWFLAKE.CORTEX_EMBED_USER` database role |
| Feedback tool | `CREATE TABLE` and `CREATE PROCEDURE` on the feedback schema |
| `cortex_agent_evaluation` | `CREATE STAGE` on the schema; see [Agent Evaluations](#agent-evaluations) for what starting a run needs |
| `revoke_unlisted_grants` | to have made the grants being revoked, or `MANAGE GRANTS` |

### Roles that use the objects

The grants options (`agent_grants`, `search_service_grants`, `mcp_server_grants`) grant privileges on **the object itself and nothing else**. Snowflake is explicit that `USAGE` on an agent is not sufficient on its own. A role that calls an agent also needs:

- `USAGE` on the database and schema containing the agent, and on those containing each tool's object
- a Cortex database role: `SNOWFLAKE.CORTEX_USER` (granted to `PUBLIC` by default) or `SNOWFLAKE.CORTEX_AGENT_USER`, plus `SNOWFLAKE.CORTEX_ANALYST_USER` if the agent uses Cortex Analyst tools
- `USAGE` on every Cortex Search Service the agent searches
- `SELECT` on every semantic view the agent queries
- `USAGE` on every function or procedure used as a custom tool (the package grants this for its own `AGENT_SUBMIT_FEEDBACK` procedure)
- `USAGE` on every warehouse named in a tool's `execution_environment`

The same applies to an MCP server: `USAGE` on the server lets a role connect and call tools, and each tool's underlying object needs its own grant. Tools of type `SYSTEM_EXECUTE_SQL` additionally require `SNOWFLAKE.CORTEX_USER` or `SNOWFLAKE.CORTEX_AGENT_USER`.

A Cortex Search Service runs with **owner's rights**: any role with `USAGE` on the service can retrieve everything it indexes, whatever that role's privileges on the source tables, and masking and row access policies are evaluated as the owner. Grant `USAGE` on a service accordingly.

To grant across a whole schema rather than per object, Snowflake supports future grants, which also survive a replace — e.g. `GRANT USAGE ON FUTURE AGENTS IN SCHEMA my_db.my_schema TO ROLE analyst_role;`.

## Feedback Tool

All agents share a single feedback table and a single `AGENT_SUBMIT_FEEDBACK` procedure — no config required. On each `dbt run` the materialization provisions (idempotently):

1. A **feedback table** named `AGENT_FEEDBACK` in the agent's database and schema, with columns: `feedback_id`, `agent_name`, `user_name`, `rating`, `comment`, `conversation_history`, `created_at`
2. A **stored procedure** named `AGENT_SUBMIT_FEEDBACK` in the same location

By default both land in the agent's own schema. Use `feedback_schema` to place them in a shared schema instead:

```sql
{{ config(
    materialized='cortex_agent',
    meta={'feedback_schema': 'SHARED_SCHEMA'}
) }}
```

Or with an explicit database:

```sql
{{ config(
    materialized='cortex_agent',
    meta={'feedback_schema': 'MY_DB.SHARED_SCHEMA'}
) }}
```

To override the table name independently of the schema, use `feedback_table`:

```sql
{{ config(
    materialized='cortex_agent',
    meta={
        'feedback_schema': 'SHARED_SCHEMA',
        'feedback_table': 'MY_DB.SHARED_SCHEMA.AGENT_FEEDBACK'
    }
) }}
```

To enable feedback provisioning, set `create_feedback_table: true`:

```sql
{{ config(
    materialized='cortex_agent',
    meta={'create_feedback_table': true}
) }}
```

> Snowflake also records feedback natively: a REST endpoint (`POST .../agents/{name}:feedback`) stores it as AI Observability events, readable with `SNOWFLAKE.LOCAL.GET_AI_OBSERVABILITY_EVENTS` by a role holding `MONITOR` on the agent. That path has no SQL or in-conversation equivalent, and feedback text is redacted without the `READ UNREDACTED AI OBSERVABILITY EVENTS TABLE` account privilege. The tool below is for capturing feedback from inside the conversation into a table you own.

Add the tool entry to your spec body so the agent can call it. Update the `identifier` to match your `feedback_schema` if you set one:

```sql
{{ config(
    materialized='cortex_agent',
    meta={'feedback_schema': 'SHARED_SCHEMA'}
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
    meta={'create_feedback_table': true, 'feedback_execute_as': 'owner'}
) }}
```

The procedure is recreated on every `dbt run`, so changes to the feedback table schema are picked up automatically. The feedback table uses `CREATE TABLE IF NOT EXISTS`, so existing data is never dropped.

Roles listed in `agent_grants` are granted `USAGE` on the `AGENT_SUBMIT_FEEDBACK` procedure as well as on the agent — `USAGE` on an agent does not by itself let a role call the agent's custom tools. The procedure is replaced with `COPY GRANTS`, so grants issued for other agents sharing the same feedback schema are kept. With `feedback_execute_as: 'caller'` those roles also need `INSERT` on the feedback table, which you grant yourself.

## MCP Servers

The package also ships an `mcp_server` materialization for deploying [Snowflake-managed MCP servers](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-mcp). It works the same way as `cortex_agent`: the model body is the raw MCP server YAML specification (a `tools:` array), wrapped in `CREATE OR REPLACE MCP SERVER ... FROM SPECIFICATION $$ ... $$`.

```sql
-- models/mcp/data_mcp_server.sql
{{ config(
    materialized='mcp_server',
    meta={'mcp_server_grants': ['mcp_access_role']}
) }}

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

- The spec needs a `tools` array, a `tool_config` list, or both. Supported tool `type` values are `CORTEX_SEARCH_SERVICE_QUERY`, `CORTEX_ANALYST_MESSAGE` (semantic views only), `CORTEX_AGENT_RUN`, `SYSTEM_EXECUTE_SQL`, `GENERIC`, and `CODING_AGENT`. Each tool that wraps an existing object needs a fully-qualified `identifier` — use `{{ ref() }}` to wire it into the dbt DAG so the MCP server always runs after its upstream objects.
- `tool_config` with `type: "CORTEX_AGENT_RUN"` and `selection: "all"` exposes every agent the caller can use, without listing each one. `GENERIC` and `CORTEX_AGENT_RUN` tools accept optional `annotations` (`readOnlyHint`, `destructiveHint`, `idempotentHint`, `openWorldHint`), which are hints to the client, not enforcement.
- A server is limited to 50 tools. A server that exposes `SYSTEM_EXECUTE_SQL` lets clients run SQL directly rather than going through an agent; Snowflake recommends keeping that on a separate server from governed, agent-only access.
- Unlike agents, the MCP server DDL has **no `COMMENT` or `PROFILE` clause**, so everything except access grants lives in the spec body.
- **Grants are dropped on every run unless you list them.** Snowflake has no `ALTER MCP SERVER` and no `COPY GRANTS` for MCP servers, so each `dbt run` replaces the server and Snowflake drops every grant on it. Set `mcp_server_grants` (a list of role names, or a privilege map — see [Grants](#grants)) and the materialization re-issues `GRANT USAGE ON MCP SERVER` after each replace. A grant made by hand will not survive the next run.
- `USAGE` on the server lets a role connect, list tools and call them, but **not** use the objects behind the tools. The role separately needs `USAGE` on each search service, agent, function or procedure, `SELECT` on each semantic view, and `USAGE` on the warehouse.
- Like `cortex_agent`, every `dbt run` issues `CREATE OR REPLACE MCP SERVER`, so re-runs are fully idempotent, and Jinja (`{{ ref() }}`, `{{ var() }}`, etc.) works anywhere in the spec.
- To drop an MCP server explicitly, use the helper macro in a dbt operation or post-hook: `{% do run_query(dbt_cortex_agent.snowflake__get_drop_mcp_server_sql(this)) %}` (or run `DROP MCP SERVER IF EXISTS <db>.<schema>.<name>;` directly).

| Option | Type | Required | Description |
|---|---|---|---|
| `materialized` | string | Yes | Must be `'mcp_server'` |
| `mcp_server_grants` | list or map | No | Who gets access to the server. A list of role names grants `USAGE` to each; a map grants any MCP server privilege. Re-issued after every run. See [Grants](#grants). |

Refer to the [Snowflake CREATE MCP SERVER docs](https://docs.snowflake.com/en/sql-reference/sql/create-mcp-server) for the full and up-to-date specification reference.

## Cortex Search Services

The package also ships a `cortex_search_service` materialization for deploying [Snowflake Cortex Search Services](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-search/cortex-search-overview) — the backing search index used by a `cortex_search` tool on a Cortex Agent, or a `CORTEX_SEARCH_SERVICE_QUERY` tool on an MCP server.

Unlike `cortex_agent` and `mcp_server`, this materialization is **not** a YAML passthrough. The model body is a normal dbt `SELECT` query, which becomes the `AS <query>` clause of `CREATE CORTEX SEARCH SERVICE`. All other DDL clauses (search column, attributes, warehouse, target lag, etc.) come from the model's config.

Only the single-index syntax (`ON <search_column>` + `ATTRIBUTES`) is supported. If you need to search over multiple text fields, blend them into one column in the model's `SELECT` (e.g. `short_description || ' ' || long_description || ' ' || synonyms as search_text`) and keep the individual columns as `ATTRIBUTES` for filtering/display.

> `PRIMARY KEY` columns must be `TEXT` — Cortex Search Service rejects numeric types for `PRIMARY KEY` regardless of precision/scale, failing with `Invalid column type NUMBER(n,0) for source query column <col>`. Cast numeric ID columns to a string type, e.g. `id::varchar`, before using them in `primary_key`.

```sql
-- models/search/product_search.sql
{{ config(
    materialized='cortex_search_service',
    meta={
        'search_column': 'search_text',
        'attributes': ['id', 'title', 'category'],
        'target_lag': '1 hour',
        'primary_key': ['id'],
        'comment': 'Product search index for the shopping assistant agent'
    }
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

As with agents, set every option except `materialized` under `meta` (see [dbt v2](#dbt-v2)).

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
| `search_service_grants` | list or map | No | Who gets access to the service. A list of role names grants `USAGE` to each; a map grants any search service privilege. See [Grants](#grants). |
| `revoke_unlisted_grants` | bool | No | Revoke privileges held on the service by account roles that `search_service_grants` does not list. Defaults to `false`. See [Grants](#grants). |

### How It Works

- **First run for a service, or `dbt run --full-refresh`:** issues `CREATE OR REPLACE CORTEX SEARCH SERVICE ... AS <query>` with the full set of configured options.
- **Every other run:** issues `ALTER CORTEX SEARCH SERVICE ... SET` to update only the mutable properties (`target_lag`, `warehouse`, `comment`, `auto_suspend`, `request_logging`, `full_index_build_interval_days`, `attributes`, `primary_key`) in place.

This split matters because `CREATE OR REPLACE` forces Snowflake to fully rebuild the search index from scratch. Unlike `mcp_server`, which issues `CREATE OR REPLACE` on every run because MCP server definitions are cheap to redefine, `cortex_search_service` avoids doing that on steady-state runs — recreating the service on every `dbt run` would discard Cortex Search's own incremental refresh and be wasteful and slow for anything beyond trivial data volumes.

`search_column`, `embedding_model`, `refresh_mode`, `initialize`, and the defining query itself are immutable once the service is created. To change any of those, run `dbt run --full-refresh`.

A normal run cannot apply a change to those properties, so it does not try:

- A changed `search_column` or `embedding_model` is detected and reported as a **warning** naming the configured and deployed values. The deployed service is left as it was.
- A changed **query**, `refresh_mode` or `initialize` **cannot be detected** — Snowflake does not expose them in a form that can be compared — so the edit is silently not applied. After changing the model's `SELECT`, always run `dbt run --full-refresh --select <model>`.

`CREATE OR REPLACE` is not free: from the moment it commits until the new index has finished building, the service cannot answer queries, and existing grants are dropped (the materialization re-issues those in `search_service_grants`).

## Agent Evaluations

The `cortex_agent_evaluation` materialization version-controls a [Cortex Agent evaluation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-evaluations) run configuration. The model body is the evaluation YAML (`dataset`, `evaluation` and `metrics` blocks). On every run the materialization writes it to a stage as `<model>.yaml`; it only starts a (paid) evaluation run when asked to.

```sql
-- models/evals/revenue_assistant_eval.sql
{{ config(materialized='cortex_agent_evaluation', tags=['eval']) }}

evaluation:
  agent_params:
    agent_name: "{{ ref('revenue_assistant') }}"
    agent_type: "CORTEX AGENT"
  source_metadata:
    type: "dataset"
    dataset_name: "REVENUE_ASSISTANT_EVAL_SET"

metrics:
  - answer_correctness
  - logical_consistency
```

Use `{{ ref() }}` for the agent (and for `dataset.table_name`, if you include a `dataset` block) so the config is redeployed after the objects it points at. Write prose as Jinja comments (`{# ... #}`), not SQL `--` comments: the body is written to the file verbatim, and `--` is not a YAML comment.

| Option | Type | Required | Description |
|---|---|---|---|
| `materialized` | string | Yes | Must be `'cortex_agent_evaluation'` |
| `stage` | string | No | Fully-qualified stage that holds the config files. Defaults to `{database}.{schema}.CORTEX_EVAL_CONFIGS`, created if missing. |
| `run_on_build` | bool | No | Start an evaluation run on every `dbt run`. Defaults to `false`. |
| `run_name` | string | No | Evaluation run name. Defaults to `<model>_<run start timestamp>`, which keeps names unique. |

Start a run yourself with:

```sql
CALL EXECUTE_AI_EVALUATION(
  'START',
  OBJECT_CONSTRUCT('run_name', 'revenue_assistant_eval_2026_11_25'),
  '@my_db.my_schema.CORTEX_EVAL_CONFIGS/revenue_assistant_eval.yaml'
);
```

`'STATUS'`, `'CANCEL'` and `'DELETE'` take the same arguments. Read results with `SNOWFLAKE.LOCAL.GET_AI_EVALUATION_DATA('<db>', '<schema>', '<agent>', 'CORTEX AGENT', '<run_name>')`.

Things to know:

- **Runs cost credits.** The agent is invoked once per dataset row and an LLM judge scores each metric per row. That is why `run_on_build` defaults to `false`.
- **The `dataset` block is for the first run only.** With a `dataset` block present, each `START` tries to create the dataset again, and Snowflake documents that a run can fail when `dataset_name` already exists. Once the dataset is registered, remove the block and keep `evaluation.source_metadata.dataset_name` pointing at it — or create the dataset separately with `SYSTEM$CREATE_EVALUATION_DATASET`.
- **Evaluating a specific agent version.** Add `agent_version` under `agent_params` — a version (`VERSION$3`), an alias, or `LIVE`, `FIRST`, `LAST`, `DEFAULT`. When omitted, Snowflake evaluates the default version once the agent has two or more committed versions.
- **Metric versions.** A metric given as a plain string uses the current default version, which Snowflake moves forward over time; scores from different metric versions are not comparable. To keep a series comparable, pin it: `- name: "answer_correctness"` / `version: "v3"`. Metric version `v1` has reached end-of-life, and runs pinned to it fail.
- **Ground truth is a `VARIANT`.** Use `PARSE_JSON` or `TO_VARIANT` in the dataset model; `OBJECT_CONSTRUCT` returns an `OBJECT` and is not accepted.
- **Privileges to start a run:** `USAGE` (or `OWNERSHIP`) **and** `MONITOR` (or `OWNERSHIP`) on the agent — grant the latter with `agent_grants: {'monitor': [...]}` — plus `EXECUTE TASK ON ACCOUNT`, `READ` on the config stage, `CREATE TASK` and `CREATE FILE FORMAT` on the current schema, `CREATE DATASET` on the dataset's schema when creating one, a Cortex database role, and access to every tool the agent uses. If the account restricts model access and the role cannot use the judge model, Snowflake reports **scores of 0 with no error**.

## Testing

The package has two test suites.

### Unit tests (offline)

`unit_tests/` is a small dbt project whose models call the package's macros and assert on what they return — the SQL generated for every `CREATE`, `ALTER`, `DROP`, `GRANT` and `REVOKE`, how config options are read from `meta`, how grants options are normalised, and the name-matching and drift-detection logic. A failed assertion is a compiler error, so `dbt compile` is the test run. Nothing connects to Snowflake.

```bash
./scripts/run_unit_tests.sh
```

The script uses whichever `dbt` is on your `PATH`:

- **dbt v1** — also needs `dbt-duckdb` (`pip install dbt-core dbt-duckdb`); dbt Core opens a connection on compile, and an in-memory DuckDB database gives it one.
- **dbt v2** — `pip install dbt`; compiles offline with placeholder Snowflake values.

It then re-compiles the cases in `unit_tests/expected_errors.txt`, each of which must *fail* with a specific message (for example, trying to grant `OWNERSHIP`).

To add a test, add assertions to a model in `unit_tests/models/` using the helpers in `unit_tests/macros/assertions.sql` (`assert_equal`, `assert_sql`, `assert_contains`, ...). Keep them inside the model's `{% if execute %}` block.

### Integration tests (Snowflake)

`integration_tests/` deploys real agents, MCP servers, search services and evaluation configs into a Snowflake schema and asserts on the result with singular tests. Because `SHOW` and `DESCRIBE` cannot be used as subqueries, "capture" models (`*_describe`, `*_versions`, `*_grants`) run the statement in a pre-hook and store its output in a table for the tests to read.

Some behaviour only appears on a **second** run against existing objects: the `ALTER CORTEX SEARCH SERVICE` path, committing a second agent version when the spec changes (and none when it doesn't), re-applying an agent's comment and profile, and `COPY GRANTS` on `CREATE OR REPLACE AGENT`. CI therefore runs the models twice — the second time with `--vars '{second_run: true}'` — then runs the versioned agents once more with `--full-refresh`, which must leave their history intact, before running the tests with the same var:

```bash
cd integration_tests
dbt deps
dbt run
dbt run --vars '{second_run: true}'
dbt run --full-refresh --select cortex_agent_versioned_test cortex_agent_versioned_test_versions cortex_agent_unchanged_test cortex_agent_unchanged_test_versions --vars '{second_run: true}'
dbt test --vars '{second_run: true}'
```

Tests that depend on the second run pass trivially when the var is not set, so a single `dbt build` still works.

The grant tests grant to and revoke from a role named `dbt_demo_role`, which must exist in the test account.

Both suites run in CI on dbt v1 and dbt v2. The unit tests run on every pull request; the integration tests need the Snowflake secrets and run for pull requests targeting `master`.

## Local Development

### Prerequisites

- PowerShell, for `scripts/run_tests.ps1` (the integration test runner); the unit test runner `scripts/run_unit_tests.sh` needs a POSIX shell
- dbt installed in your environment (`pip install dbt-snowflake` for dbt v1, or `pip install dbt` for dbt v2)
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

> `run_tests.ps1` runs the models once. CI runs them twice to reach the ALTER and second-version paths — see [Testing](#testing) for the commands.

To install packages only (no build):

```powershell
.\scripts\run_tests.ps1 -DepsOnly
```

## License

[Apache License 2.0](LICENSE)
