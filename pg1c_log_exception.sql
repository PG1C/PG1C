set client_encoding='UTF8';

create extension if not exists dblink;

create or replace function pg1c.log_dblink() returns varchar language plpgsql as $$
begin
  return 'dbname='||current_database();
end; $$;

-- Проверка локального подключения, при возникновении ошибки нужно поправить функцию pg1c.log_dblink() или файл pg_hba.conf   
select pg1c.log_dblink() dblink,access from dblink(pg1c.log_dblink(),'select true') as t(access boolean);

create or replace function pg1c.log_metadata_sql_fn_commit() returns trigger security definer language plpgsql as $$
begin
  update pg1c.log_metadata_sql set transaction_fixed=true where id=new.id;  
  return null;
end; $$;

create or replace procedure pg1c.execute_metadata_sql(server_1c varchar, table_1c varchar, statement text) language plpgsql as $$
declare
  v_log_id bigint;
  v_exception text;
begin
  v_log_id := (
    select id from dblink(pg1c.log_dblink(),      
      'insert into pg1c.log_metadata_sql(db_user,server_1c,table_1c,statement,transaction_fixed)'||
      '  values('||quote_literal(session_user)||','||quote_literal(server_1c)||','||quote_literal(table_1c)||','||quote_literal(statement)||',false)'||
      '  returning id'
    ) as t(id bigint)
  );
  if to_regtype('pg1c_log_metadata_sql') is null then
    create temporary table pg1c_log_metadata_sql(id bigint) on commit drop;
    create constraint trigger log_metadata_sql_tg_commit after insert on pg1c_log_metadata_sql deferrable initially deferred for each row execute procedure pg1c.log_metadata_sql_fn_commit();   
  end if;
  insert into pg1c_log_metadata_sql values (v_log_id);
  execute statement; 
exception when others then  
  v_exception := format(E'PG1C-8107 Ошибка при изменении метаданных для таблицы 1C %s: [%s] %s\nSQL statement: %s', quote_literal(table_1c), SQLSTATE, SQLERRM, statement);
  perform dblink_exec(pg1c.log_dblink(),'update pg1c.log_metadata_sql set exception='||quote_literal(v_exception)||' where id='||v_log_id); 
  raise exception using
    errcode = 'S8107',
    message = v_exception,
    hint    = 'Обратитесь в техническую поддержку https://pg1c.org/ru/contacts/#support';
end; $$;

create or replace function pg1c.log_http_request_fn_commit() returns trigger security definer language plpgsql as $$
begin
  update pg1c.log_http_request set transaction_fixed=true where id=new.id;  
  return null;
end; $$;

create or replace procedure pg1c.log_http_request(timestamp_ timestamptz, server_1c varchar, urn varchar, exception text) language plpgsql as $$
declare
  v_log_id bigint;
  v_timestamp varchar := quote_literal(timestamp_::text)||'::timestamptz';
  v_url varchar := pg1c.http_url(urn,server_1c,true);
begin
  v_log_id := (
    select id from dblink(pg1c.log_dblink(),
	  'insert into pg1c.log_http_request(timestamp,duration,server_1c,url,transaction_fixed,exception)'||
      '  values ('||v_timestamp||',clock_timestamp()-'||v_timestamp||','||quote_literal(server_1c)||','||quote_literal(v_url)||',false,'||quote_nullable(exception)||')'||
      '  returning id'
    ) as t(id bigint)
  );
  if to_regtype('pg1c_log_http_request') is null then
    create temporary table pg1c_log_http_request(id bigint) on commit drop;
    create constraint trigger log_http_request_tg_commit after insert on pg1c_log_http_request deferrable initially deferred for each row execute procedure pg1c.log_http_request_fn_commit();   
  end if;
  insert into pg1c_log_http_request values (v_log_id);   
end; $$;