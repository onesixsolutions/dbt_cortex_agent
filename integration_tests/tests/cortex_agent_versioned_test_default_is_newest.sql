-- Verify the newest committed version is also the DEFAULT version — what end users get and
-- what Snowsight shows as "In use".
--
-- COMMIT creates a version but does not move the DEFAULT pointer; Snowflake follows the latest
-- version only implicitly, and stops once DEFAULT_VERSION is set out-of-band (e.g. Snowsight's
-- Publish button). Without this assertion an agent can accumulate committed versions that no
-- user ever sees, and the suite would still pass — cortex_agent_versioned_test_has_versions
-- only checks that versions exist, not that the newest one is live.
--
-- SHOW VERSIONS emits lowercase column names, so they must be double-quoted here. Rows with a
-- null "name" are the mutable LIVE working copy, not committed versions, so they're excluded.
-- Returns 0 rows on success (standard dbt test contract).

with committed as (

    select
        "name"                                            as version_name,
        "is_default"                                      as is_default,
        try_to_number(split_part("name", '$', 2))         as version_number
    from {{ ref('cortex_agent_versioned_test_versions') }}
    where "name" is not null

),

newest as (
    select version_name from committed order by version_number desc limit 1
),

current_default as (
    select version_name from committed where lower(is_default) = 'true'
)

select
    'newest committed version is not the default: newest='
        || coalesce((select version_name from newest), '<none>')
        || ', default='
        || coalesce((select version_name from current_default), '<none>') as error
where (select version_name from newest) is distinct from (select version_name from current_default)
