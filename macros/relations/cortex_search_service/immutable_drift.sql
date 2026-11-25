-- Compares the configured values of properties that are fixed when a Cortex Search Service is
-- created against what is actually deployed, and returns a LIST of warning messages (empty
-- when nothing has drifted).
--
-- Called on the ALTER path of the cortex_search_service materialization, where these
-- properties cannot be applied: without this check, editing `search_column` or
-- `embedding_model` in a model's config changes nothing and says nothing.
--
-- Only search_column and embedding_model are compared. refresh_mode and initialize are not
-- returned by SHOW or DESCRIBE, and the defining query is stored by Snowflake in a form that
-- cannot be compared reliably with the compiled model.
-- Args:
--   relation                 : the target relation object
--   search_column            : configured search column
--   embedding_model          : configured embedding model, or none when left to the default
--   deployed_search_column   : `search_column` from SHOW CORTEX SEARCH SERVICES
--   deployed_embedding_model : `embedding_model` from DESCRIBE CORTEX SEARCH SERVICE, or none
--                              when it was not looked up
{% macro get_search_service_immutable_drift(relation, search_column, embedding_model, deployed_search_column, deployed_embedding_model) %}
  {%- set _name = relation.database ~ '.' ~ relation.schema ~ '.' ~ relation.identifier -%}
  {%- set _hint = " This property is fixed when the service is created, so the change has NOT been applied. Run this model with `dbt run --full-refresh` to rebuild the service with it." -%}
  {%- set _messages = [] -%}
  {%- if search_column is not none and deployed_search_column is not none
        and (search_column | string | replace('"', '') | upper) != (deployed_search_column | string | replace('"', '') | upper) -%}
    {%- do _messages.append("Cortex Search Service " ~ _name ~ ": `search_column` is configured as '" ~ search_column ~ "' but the deployed service searches '" ~ deployed_search_column ~ "'." ~ _hint) -%}
  {%- endif -%}
  {%- if embedding_model is not none and deployed_embedding_model is not none
        and (embedding_model | string | lower) != (deployed_embedding_model | string | lower) -%}
    {%- do _messages.append("Cortex Search Service " ~ _name ~ ": `embedding_model` is configured as '" ~ embedding_model ~ "' but the deployed service uses '" ~ deployed_embedding_model ~ "'." ~ _hint) -%}
  {%- endif -%}
  {{ return(_messages) }}
{% endmacro %}
