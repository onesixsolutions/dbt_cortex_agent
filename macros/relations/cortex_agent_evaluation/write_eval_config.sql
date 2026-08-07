-- Writes the compiled evaluation run-config YAML (the model body) to <stage>/<file_name>
-- as a single, verbatim text file using the COPY INTO single-file unload trick.
--
-- FIELD_OPTIONALLY_ENCLOSED_BY and ESCAPE_UNENCLOSED_FIELD are disabled and COMPRESSION is
-- off so the multi-line YAML is written byte-for-byte (no quoting/escaping/gzip). OVERWRITE
-- keeps a single current config file per model. Verified to round-trip identically.
{% macro snowflake__write_eval_config(stage, file_name, config_yaml) %}

  copy into @{{ stage }}/{{ file_name }}
  from (select $${{ config_yaml | trim }}$$)
  file_format = (
    type = csv
    compression = none
    field_optionally_enclosed_by = none
    escape_unenclosed_field = none
  )
  single = true
  overwrite = true
  header = false
  max_file_size = 67108864

{% endmacro %}
