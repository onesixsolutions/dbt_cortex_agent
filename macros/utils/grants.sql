-- Shared grant handling for the cortex_agent, cortex_search_service and mcp_server
-- materializations.
--
-- A grants option (`agent_grants`, `search_service_grants`, `mcp_server_grants`) accepts
-- either form:
--
--   a list of grantees  -> each is granted USAGE (the original behaviour)
--       ['analyst_role', 'support_role']
--
--   a map of privilege -> grantee or list of grantees, like dbt's native `grants` config
--       {'usage': ['analyst_role'], 'monitor': ['ops_role']}
--
-- A grantee is an account role name by default. Prefix it with `database role ` to grant to
-- a database role instead: 'database role MY_DB.READER'.


-- Normalises a grants option into a map of lower-cased privilege -> list of grantees.
-- OWNERSHIP is rejected: it is transferred with GRANT OWNERSHIP, not granted alongside other
-- privileges, and handing it away would stop dbt from managing the object.
{% macro normalize_grants(grants, option_name='grants') %}
  {%- set _normalized = {} -%}
  {%- if grants is none -%}
  {%- elif grants is mapping -%}
    {%- for _privilege, _grantees in grants.items() -%}
      {%- set _key = _privilege | string | trim | lower -%}
      {%- if _key == 'ownership' -%}
        {{ exceptions.raise_compiler_error("`" ~ option_name ~ "` cannot grant OWNERSHIP. Transfer ownership with GRANT OWNERSHIP outside of dbt instead.") }}
      {%- endif -%}
      {%- if _grantees is none -%}
        {%- set _grantee_list = [] -%}
      {%- elif _grantees is string -%}
        {%- set _grantee_list = [_grantees] -%}
      {%- else -%}
        {%- set _grantee_list = _grantees -%}
      {%- endif -%}
      {%- do _normalized.update({_key: _grantee_list}) -%}
    {%- endfor -%}
  {%- elif grants is string -%}
    {%- do _normalized.update({'usage': [grants]}) -%}
  {%- else -%}
    {%- do _normalized.update({'usage': grants}) -%}
  {%- endif -%}
  {{ return(_normalized) }}
{% endmacro %}


-- Turns a grantee from a grants option into the `<kind> <name>` clause used after TO / FROM.
--   'analyst_role'                  -> role analyst_role
--   'database role MY_DB.READER'    -> database role MY_DB.READER
{% macro grantee_clause(grantee) %}
  {%- set _grantee = grantee | string | trim -%}
  {%- set _lower = _grantee | lower -%}
  {%- if _lower.startswith('database role ') or _lower.startswith('role ') -%}
    {{ return(_grantee) }}
  {%- else -%}
    {{ return('role ' ~ _grantee) }}
  {%- endif -%}
{% endmacro %}


-- Builds one GRANT statement per privilege/grantee pair.
-- Returns a LIST of SQL strings; callers execute each as its own statement.
-- Args:
--   object_type   : SQL object type keyword(s), e.g. 'agent', 'cortex search service', 'mcp server'
--   object_name   : fully-qualified object name (for a procedure, include the argument types)
--   grants        : a grants option in either accepted form (see the top of this file)
--   option_name   : config option name, used in error messages
{% macro get_grant_statements(object_type, object_name, grants, option_name='grants') %}
  {%- set _statements = [] -%}
  {%- for _privilege, _grantees in dbt_cortex_agent.normalize_grants(grants, option_name).items() -%}
    {%- for _grantee in _grantees -%}
      {%- do _statements.append('grant ' ~ _privilege ~ ' on ' ~ object_type ~ ' ' ~ object_name ~ ' to ' ~ dbt_cortex_agent.grantee_clause(_grantee)) -%}
    {%- endfor -%}
  {%- endfor -%}
  {{ return(_statements) }}
{% endmacro %}


-- Builds REVOKE statements for privileges that are currently granted on an object but are not
-- listed in its grants option. Used when `revoke_unlisted_grants` is true, to make the grants
-- option the full definition of who has access rather than an additive list.
--
-- Deliberately conservative:
--   * only grants to ACCOUNT ROLES are considered. Grants to database roles, shares and
--     application roles are never revoked.
--   * OWNERSHIP is never revoked.
--   * Snowflake only lets a role revoke grants that it (or a role below it) made, unless it
--     holds MANAGE GRANTS. A grant made by an unrelated role makes the REVOKE fail, which
--     fails the model: that is the signal to remove it by hand or grant MANAGE GRANTS.
--
-- Runs SHOW GRANTS ON <object>, so it must be called after the object exists.
-- Returns a LIST of SQL strings.
{% macro get_revoke_unlisted_grant_statements(object_type, object_name, grants, option_name='grants') %}
  {%- set _rows = run_query('show grants on ' ~ object_type ~ ' ' ~ object_name) -%}
  {{ return(dbt_cortex_agent.get_revoke_statements_for_rows(object_type, object_name, grants, _rows.rows, option_name)) }}
{% endmacro %}


-- The comparison half of get_revoke_unlisted_grant_statements, separated from the SHOW GRANTS
-- query so it can be exercised without a Snowflake connection.
-- `current_grants` is an iterable of rows exposing `privilege`, `granted_to` and
-- `grantee_name`, as returned by SHOW GRANTS ON <object>.
{% macro get_revoke_statements_for_rows(object_type, object_name, grants, current_grants, option_name='grants') %}
  {%- set _wanted = [] -%}
  {%- for _privilege, _grantees in dbt_cortex_agent.normalize_grants(grants, option_name).items() -%}
    {%- for _grantee in _grantees -%}
      {%- set _clause = dbt_cortex_agent.grantee_clause(_grantee) -%}
      {%- if (_clause | lower).startswith('role ') -%}
        {%- set _name = _clause[5:] | trim -%}
        {#- An unquoted identifier is stored upper-cased; a double-quoted one is stored as written. -#}
        {%- if _name.startswith('"') -%}
          {%- set _name = _name | replace('"', '') -%}
        {%- else -%}
          {%- set _name = _name | upper -%}
        {%- endif -%}
        {%- do _wanted.append((_privilege | upper) ~ '|' ~ _name) -%}
      {%- endif -%}
    {%- endfor -%}
  {%- endfor -%}

  {%- set _statements = [] -%}
  {%- for _row in current_grants -%}
    {%- set _privilege = _row['privilege'] | string | upper -%}
    {%- set _granted_to = _row['granted_to'] | string | upper -%}
    {%- set _grantee_name = _row['grantee_name'] | string -%}
    {%- if _granted_to == 'ROLE' and _privilege != 'OWNERSHIP' and (_privilege ~ '|' ~ _grantee_name) not in _wanted -%}
      {%- do _statements.append('revoke ' ~ (_privilege | lower) ~ ' on ' ~ object_type ~ ' ' ~ object_name ~ ' from role "' ~ _grantee_name ~ '"') -%}
    {%- endif -%}
  {%- endfor -%}
  {{ return(_statements) }}
{% endmacro %}
