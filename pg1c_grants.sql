grant usage on schema pg1c to :roles;

grant execute on function  pg1c.create_table          to :roles;
grant execute on function  pg1c.create_table_only     to :roles;
grant execute on procedure pg1c.create_table_all      to :roles;
grant execute on procedure pg1c.refresh_metadata      to :roles;
grant execute on procedure pg1c.refresh_metadata_only to :roles;
grant execute on procedure pg1c.refresh_data          to :roles;
grant execute on procedure pg1c.refresh_data_all      to :roles;
grant execute on procedure pg1c.refresh_all           to :roles;
grant execute on procedure pg1c.drop_table            to :roles;
grant execute on procedure pg1c.drop_table_all        to :roles;

grant execute on procedure pg1c.lock_server_1c                        to :roles;
grant execute on function  pg1c.http_request(varchar,varchar,varchar) to :roles;

grant execute on function pg1c.xml_utf8_encode to :roles;
grant execute on function pg1c.xml_utf8_decode to :roles;
grant execute on function pg1c.metadata_tables to :roles;
grant execute on function pg1c.table           to :roles;
grant execute on function pg1c.value_any       to :roles;
grant execute on function pg1c.type_ref_to_pg  to :roles;

grant select(id,web_address,web_port,publication,schema_expression,owner_expression,names_pg_short) on pg1c.server_1c to :roles;
grant select,update(row_count,refresh_data_timestamp,refresh_data_duration)                         on pg1c.table     to :roles;
