\echo Use "CREATE EXTENSION pg1c" to load this file. \quit
;

set client_encoding = 'UTF8';

create or replace function pg1c.version() returns varchar language plpgsql as $$
begin
  return '25.4';
end; $$;

create table if not exists pg1c.server_1c(
  id varchar primary key,
  web_address inet not null,
  web_port int not null default 80,  
  publication varchar not null,
  user_1c varchar not null default '',
  password_1c varchar not null default '',
  auth_expression boolean not null default false,
  schema_expression varchar not null default '$1',
  owner_expression varchar not null default 'session_user',
  names_pg_short boolean not null default false,
  memory_buffer_mb int not null default greatest(pg_size_bytes(current_setting('maintenance_work_mem'))/1024/1024,32),
  check_updates boolean default true,
  check_updates_timestamp timestamptz
);

insert into pg1c.server_1c(id, web_address, publication)
  values ('DEFAULT', '127.0.0.1', 'InfoBase')
  on conflict do nothing;
 
create table if not exists pg1c.metadata_type(
  type varchar primary key,
  name varchar not null unique  
);

create table if not exists pg1c.table(
  server_1c varchar references pg1c.server_1c, 
  name_1c varchar,
  primary key (server_1c,name_1c),
  metadata_type varchar not null references pg1c.metadata_type(type),
  schema name not null,
  name_pg name not null,
  unique (schema,name_pg),
  fetch_size int not null default greatest(pg_size_bytes(current_setting('maintenance_work_mem'))/1024/1024/32,1)*5000,  
  row_count int,
  refresh_metadata_timestamp timestamptz not null,
  refresh_data_timestamp timestamptz, 
  refresh_data_duration interval
);

create table if not exists pg1c.table_section(
  server_1c varchar, 
  table_1c varchar,
  foreign key (server_1c,table_1c) references pg1c.table on delete cascade,
  name_1c varchar not null,
  primary key (server_1c,table_1c,name_1c),
  name_pg_column name not null,  
  unique (server_1c,table_1c,name_pg_column),  
  name_pg_view name not null,  
  unique (server_1c,table_1c,name_pg_view)
);

do $$ begin
  if to_regtype('pg1c.metadata_table') is null then
    create type pg1c.metadata_xml_entity_type_property as (
      name varchar,
      type varchar 
    );      
    create type pg1c.metadata_xml_entity_type as (
      server_1c varchar,
      table_1c varchar,
      name varchar,       
      type varchar, 
      type_name varchar,
      root boolean,
      properties pg1c.metadata_xml_entity_type_property[],
      properties_key varchar[],
      properties_navigation varchar[]
    );
    create type pg1c.metadata_xml_enum_type as (
      server_1c varchar,    
      table_1c varchar,    
      name varchar,
      members varchar[]
    );
    create type pg1c.metadata_column as (
      name_1c varchar,
      type_1c varchar,
      name_pg_src varchar,      
      name_pg name,      
      type_pg varchar,
      pos_pg int,
      section_idx int
    );  
    create type pg1c.metadata_table_section as (
      column_idx int,
      name_1c varchar,
      name_pg_view name,      
      columns pg1c.metadata_column[]
    );
    create type pg1c.metadata_table as (
      server_1c varchar,
      name_1c varchar,
      type varchar,
      type$enum boolean,
      type$reg_recorder boolean,
      name_metadata varchar,
      schema name,
      owner name,
      name_pg name,    
      columns pg1c.metadata_column[],
      columns_pkey int[],
      columns_sort int[],
      column_data_version int,
      sections pg1c.metadata_table_section[]
    );
  end if; 
end $$;

create table if not exists pg1c.metadata_type_column(
  metadata_type varchar references pg1c.metadata_type(type),
  name_metadata varchar,  
  primary key (metadata_type,name_metadata),
  name_pg varchar not null,
  unique (metadata_type,name_pg),
  pos_pg int not null,
  unique (metadata_type,pos_pg)  
);

insert into pg1c.metadata_type values
  ('Constant',                   'Константа'             ),
  ('Catalog',                    'Справочник'            ),  
  ('Document',                   'Документ'              ),
  ('DocumentJournal',            'ЖурналДокументов'      ),
  ('Enumeration',                'Перечисление'          ),  
  ('ChartOfCharacteristicTypes', 'ПланВидовХарактеристик'),  
  ('ChartOfAccounts',            'ПланСчетов'            ),
  ('ChartOfCalculationTypes',    'ПланВидовРасчета'      ),
  ('InformationRegister',        'РегистрСведений'       ),
  ('AccumulationRegister',       'РегистрНакопления'     ),  
  ('AccountingRegister',         'РегистрБухгалтерии'    ),
  ('CalculationRegister',        'РегистрРасчета'        ),
  ('BusinessProcess',            'БизнесПроцесс'         ),
  ('Task',                       'Задача'                ),
  ('ExchangePlan',               'ПланОбмена'            )  
  on conflict do nothing;
 
insert into pg1c.metadata_type_column values
  --
  ('Constant', 'Value',        'Значение',  -10),
  ('Constant', 'SurrogateKey', 'id',       9990),
  --  
  ('Catalog', 'Ref_Key',            'Ссылка',                     -90),
  ('Catalog', 'LineNumber',         'НомерСтроки',                -80),
  ('Catalog', 'DataVersion',        'ВерсияДанных',               -70),
  ('Catalog', 'DeletionMark',       'ПометкаУдаления',            -60),
  ('Catalog', 'Parent_Key',         'Родитель',                   -50),
  ('Catalog', 'IsFolder',           'ЭтоГруппа',                  -40),
  ('Catalog', 'Code',               'Код',                        -30),
  ('Catalog', 'Description',        'Наименование',               -20),  
  ('Catalog', 'Predefined',         'Предопределенный',          9980),
  ('Catalog', 'PredefinedDataName', 'ИмяПредопределенныхДанных', 9990),
  -- 
  ('Document', 'Ref_Key',      'Ссылка',          -90),
  ('Document', 'LineNumber',   'НомерСтроки',     -80),
  ('Document', 'DataVersion',  'ВерсияДанных',    -70),
  ('Document', 'DeletionMark', 'ПометкаУдаления', -60),
  ('Document', 'Number',       'Номер',           -50),
  ('Document', 'Date',         'Дата',            -40),  
  ('Document', 'Posted',       'Проведен',        -30),
  --
  ('DocumentJournal', 'Ref',          'Ссылка',           -90),
  ('DocumentJournal', 'Date',         'Дата',             -80),
  ('DocumentJournal', 'DeletionMark', 'ПометкаУдаления',  -70),
  ('DocumentJournal', 'Number',       'Номер',            -60),
  ('DocumentJournal', 'Posted',       'Проведен',         -50),
  ('DocumentJournal', 'Type',         'Тип',             9990),
  --  
  ('ChartOfCharacteristicTypes', 'Ref_Key',            'Ссылка',                     -90),
  ('ChartOfCharacteristicTypes', 'DataVersion',        'ВерсияДанных',               -80),
  ('ChartOfCharacteristicTypes', 'DeletionMark',       'ПометкаУдаления',            -70),
  ('ChartOfCharacteristicTypes', 'Parent_Key',         'Родитель',                   -60),
  ('ChartOfCharacteristicTypes', 'IsFolder',           'ЭтоГруппа',                  -50),
  ('ChartOfCharacteristicTypes', 'Code',               'Код',                        -40),
  ('ChartOfCharacteristicTypes', 'Description',        'Наименование',               -30),
  ('ChartOfCharacteristicTypes', 'ValueType',          'ТипЗначения',                -20), 
  ('ChartOfCharacteristicTypes', 'Predefined',         'Предопределенный',          9980),
  ('ChartOfCharacteristicTypes', 'PredefinedDataName', 'ИмяПредопределенныхДанных', 9990),  
  --
  ('ChartOfAccounts', 'Ref_Key',            'Ссылка',                    -110),
  ('ChartOfAccounts', 'LineNumber',         'НомерСтроки',               -100),
  ('ChartOfAccounts', 'DataVersion',        'ВерсияДанных',               -90),
  ('ChartOfAccounts', 'DeletionMark',       'ПометкаУдаления',            -80),
  ('ChartOfAccounts', 'Parent_Key',         'Родитель',                   -70),
  ('ChartOfAccounts', 'Code',               'Код',                        -60),
  ('ChartOfAccounts', 'Description',        'Наименование',               -50),  
  ('ChartOfAccounts', 'Order',              'Порядок',                    -40),
  ('ChartOfAccounts', 'Type',               'Вид',                        -30),  
  ('ChartOfAccounts', 'OffBalance',         'Забалансовый',               -20),
  ('ChartOfAccounts', 'ExtDimensionTypes',  'ВидыСубконто',              9970),
  ('ChartOfAccounts', 'Predefined',         'Предопределенный',          9980),
  ('ChartOfAccounts', 'PredefinedDataName', 'ИмяПредопределенныхДанных', 9990),
  --
  ('ChartOfCalculationTypes', 'Ref_Key',                 'Ссылка',                     -90),
  ('ChartOfCalculationTypes', 'LineNumber',              'НомерСтроки',                -80),
  ('ChartOfCalculationTypes', 'DataVersion',             'ВерсияДанных',               -70),
  ('ChartOfCalculationTypes', 'DeletionMark',            'ПометкаУдаления',            -60),
  ('ChartOfCalculationTypes', 'Code',                    'Код',                        -50),
  ('ChartOfCalculationTypes', 'Description',             'Наименование',               -40),
  ('ChartOfCalculationTypes', 'LeadingCalculationTypes', 'ВедущиеВидыРасчета',         -30), 
  ('ChartOfCalculationTypes', 'Predefined',              'Предопределенный',          9980),
  ('ChartOfCalculationTypes', 'PredefinedDataName',      'ИмяПредопределенныхДанных', 9990),
  --
  ('InformationRegister', 'Period',        'Период',          -90),  
  ('InformationRegister', 'Recorder',      'Регистратор',     -80),
  ('InformationRegister', 'LineNumber',    'НомерСтроки',     -70),
  ('InformationRegister', 'Active',        'Активность',      -60),
  ('InformationRegister', 'SurrogateKey',  'id',             9990),
  --
  ('AccumulationRegister', 'Period',        'Период',         -90),  
  ('AccumulationRegister', 'Recorder',      'Регистратор',    -80),
  ('AccumulationRegister', 'LineNumber',    'НомерСтроки',    -70),
  ('AccumulationRegister', 'Active',        'Активность',     -60),
  ('AccumulationRegister', 'AccountDr',     'СчетДебет',      -50),  
  ('AccumulationRegister', 'AccountCr',     'СчетКредит',     -40),
  --
  ('AccountingRegister', 'Period',        'Период',      -90),
  ('AccountingRegister', 'Recorder',      'Регистратор', -80),  
  ('AccountingRegister', 'LineNumber',    'НомерСтроки', -70),
  ('AccountingRegister', 'Active',        'Активность',  -60),
  ('AccountingRegister', 'AccountDr_Key', 'СчетДт',      -50),  
  ('AccountingRegister', 'AccountCr_Key', 'СчетКт',      -40),
  --
  ('CalculationRegister', 'RegistrationPeriod',  'ПериодРегистрации', -90),
  ('CalculationRegister', 'Recorder',            'Регистратор',       -80),
  ('CalculationRegister', 'LineNumber',          'НомерСтроки',       -70),
  ('CalculationRegister', 'CalculationType_Key', 'ВидРасчета',        -60),  
  ('CalculationRegister', 'Active',              'Активность',        -50),  
  ('CalculationRegister', 'ReversingEntry',      'Сторно',            -40),  
  --
  ('BusinessProcess', 'Ref_Key',      'Ссылка',          -90),
  ('BusinessProcess', 'DataVersion',  'ВерсияДанных',    -80),
  ('BusinessProcess', 'DeletionMark', 'ПометкаУдаления', -70),
  ('BusinessProcess', 'Number',       'Номер',           -60),
  ('BusinessProcess', 'Date',         'Дата',            -50),
  ('BusinessProcess', 'Completed',    'Завершен',        -40),
  ('BusinessProcess', 'HeadTask',     'ВедущаяЗадача',   -30),
  ('BusinessProcess', 'Started',      'Стартован',       -20),
  --
  ('Task', 'Ref_Key',      'Ссылка',          -90),
  ('Task', 'DataVersion',  'ВерсияДанных',    -80),
  ('Task', 'DeletionMark', 'ПометкаУдаления', -70),
  ('Task', 'Number',       'Номер',           -60),
  ('Task', 'Date',         'Дата',            -50),
  ('Task', 'Description',  'Наименование',    -40),
  ('Task', 'Executed',     'Выполнена',       -30),
  --
  ('ExchangePlan', 'Ref_Key',      'Ссылка',             -90),
  ('ExchangePlan', 'LineNumber',   'НомерСтроки',        -80),
  ('ExchangePlan', 'DataVersion',  'ВерсияДанных',       -70),
  ('ExchangePlan', 'DeletionMark', 'ПометкаУдаления',    -60),
  ('ExchangePlan', 'Code',         'Код',                -50),
  ('ExchangePlan', 'Description',  'Наименование',       -40),
  ('ExchangePlan', 'SentNo',       'НомерОтправленного', -30),
  ('ExchangePlan', 'ReceivedNo',   'НомерПринятого',     -20),
  ('ExchangePlan', 'ExchangeDate', 'ДатаОбмена',         -10)
  --
  on conflict do nothing;
 
create or replace function pg1c.server_1c(server_1c varchar) returns pg1c.server_1c language plpgsql as $$
declare
  v_server_1c pg1c.server_1c := (select s from pg1c.server_1c s where s.id=server_1c);
begin
  if v_server_1c is null then
    raise exception using
      errcode = 'S8100',
      message = format('PG1C-8100 Сервер 1C %s не определен в PostgreSQL', quote_literal(server_1c)),
      hint    = 'Для определения нового сервера нужно создать запись в таблице pg1c.server_1c';
  end if;
  return v_server_1c; 
end; $$;

create or replace function pg1c.table(table_1c varchar, server_1c varchar) returns pg1c.table language plpgsql as $$
declare
  v_server_1c varchar := server_1c;
  v_table pg1c.table := (select t from pg1c.table t where t.server_1c=v_server_1c and t.name_1c=table_1c);
begin	
  if v_table is null then
    raise exception using
      errcode = 'S8101',
      message = format('PGSUITE-8101 Таблица 1C %s не существует в PostgreSQL', quote_literal(table_1c)),
      hint    = 'Для создания таблицы необходимо выполнить процедуру pg1c.create_table';
  end if;
  return v_table; 
end; $$;

do $$ begin
  if to_regtype('pg1c.value_any') is null then
    create type pg1c.value_any as (
      value text, 
      type varchar
    );
  end if;   
end $$;

create or replace function pg1c.metadata_type_pg(type_1c varchar, column_type boolean) returns varchar language plpgsql as $$
begin
  return case
    when column_type                                  then 'pg1c.value_any'
    when type_1c =    'Edm.Guid'                      then 'uuid'
    when type_1c =    'Edm.Int16'                     then 'int2'
    when type_1c =    'Edm.Int32'                     then 'int4'    
    when type_1c =    'Edm.Int64'                     then 'int8'        
    when type_1c =    'Edm.Double'                    then 'numeric'
    when type_1c =    'Edm.DateTime'                  then 'timestamp'
    when type_1c =    'Edm.Boolean'                   then 'bool'
    when type_1c =    'Edm.Binary'                    then 'bytea'  
    when type_1c like 'Collection(%'                  then 'regclass[]'
    when type_1c =    'StandardODATA.TypeDescription' then 'varchar[]'
    else 'text'
  end;  
end; $$;

do $block$ begin
execute $$
create or replace function pg1c.value_any(value_1c varchar, type_1c varchar) returns pg1c.value_any language plpgsql security definer as $func$
begin
  return case	
    when value_1c is null or type_1c is null or type_1c='' or type_1c= 'StandardODATA.Undefined' then (null,'null')::pg1c.value_any 
    else (
      value_1c, 
      case when substring(type_1c,1,14)='StandardODATA.' then
        case $$ || (
          select string_agg(format(E'\n          when substring(type_1c,15,%2s)=%-29s then %-25s||substring(type_1c,%s)', length(type)+1, quote_literal(type||'_'),quote_literal(name||'.'),16+length(type)), '') from pg1c.metadata_type order by 1
        ) || $$
          else 'Перечисление.'||substring(type_1c,15) 
        end  
      else pg1c.metadata_type_pg(type_1c,false)
      end
    )::pg1c.value_any
    end;
end; $func$;
$$;
execute $$
create or replace function pg1c.type_ref_to_pg(type_ref varchar) returns varchar language plpgsql as $func$
begin
  return	
    case $$ || (
          select string_agg(format(E'\n      when substring(type_ref,1,%2s)=%-32s then %-32s||substring(type_ref,%2s)', length(type)+4, quote_literal(type||'Ref.'),quote_literal(name||'.'),length(type)+5), '') from pg1c.metadata_type order by 1
    ) || $$
      when substring(type_ref,1, 8)='EnumRef.'                       then 'Перечисление.'                 ||substring(type_ref, 9)
      else type_ref
    end;
end; $func$;
$$; 
end; $block$;

create table if not exists pg1c.log_metadata_sql(
  id bigserial primary key,
  pg1c_version varchar(8) not null default pg1c.version(),
  server_1c varchar not null,
  table_1c varchar not null,
  timestamp timestamptz not null default current_timestamp,
  db_user name not null default session_user,  
  statement text not null,
  transaction_fixed boolean not null default true,
  exception text
);

create or replace procedure pg1c.execute_metadata_sql(server_1c varchar, table_1c varchar, statement text) language plpgsql as $$
begin
  insert into pg1c.log_metadata_sql(server_1c,table_1c,statement) values(server_1c,table_1c,statement);  
  execute statement;
exception when others then
  raise exception using
    errcode = 'S8107',
    message = format(E'PG1C-8107 Ошибка при изменении метаданных для таблицы 1C %s: %s\nSQL statement: %s', quote_literal(table_1c), SQLERRM, statement),
    hint    = 'Обратитесь в техническую поддержку https://pg1c.org/ru/contacts/#support';
end; $$;

create or replace procedure pg1c.execute_metadata_sql(metadata_table pg1c.metadata_table, statement text) language plpgsql as $$
begin
  call pg1c.execute_metadata_sql(metadata_table.server_1c,metadata_table.name_1c,statement);  
end; $$;

create table if not exists pg1c.log_http_request(
  id bigserial primary key,
  timestamp timestamptz not null,
  duration interval not null,
  db_user name not null default session_user,  
  server_1c varchar not null,
  url varchar not null,
  transaction_fixed boolean not null,
  exception text
);

create or replace function pg1c.http_url(urn varchar default '$metadata', server_1c varchar default 'DEFAULT', mask_password boolean default false) returns varchar language plpgsql as $func$
declare
  v_server_1c pg1c.server_1c := pg1c.server_1c(server_1c);
  v_auth varchar;
begin
  if mask_password then 
    v_server_1c.password_1c := '[Пароль]';
    if v_server_1c.auth_expression then
       v_server_1c.password_1c := quote_literal(v_server_1c.password_1c); 
    end if; 
  end if;
  if v_server_1c.auth_expression then
    execute format( $$ select %s||':'||%s||'@' $$,
                    case when v_server_1c.user_1c!=''     then v_server_1c.user_1c     else $$ '' $$ end,
                    case when v_server_1c.password_1c!='' then v_server_1c.password_1c else $$ '' $$ end)  
      into v_auth;
  else
    v_auth := case when v_server_1c.user_1c!='' then v_server_1c.user_1c||':'||v_server_1c.password_1c||'@' else '' end;
  end if;
  return 'http://'||v_auth||host(v_server_1c.web_address)||':'||v_server_1c.web_port||'/'||v_server_1c.publication||'/odata/standard.odata/'||urn;
end; $func$;

create or replace procedure pg1c.log_http_request(timestamp_ timestamptz, server_1c varchar, urn varchar, exception text) language plpgsql as $$
begin
  if exception is not null then
    return;
  end if;
  insert into pg1c.log_http_request(timestamp,duration,server_1c,url,transaction_fixed)
    values (timestamp_,clock_timestamp()-timestamp_,log_http_request.server_1c,pg1c.http_url(urn,log_http_request.server_1c,true),true);	
end; $$;

create or replace function pg1c.http_request(address bytea, port int4, auth bytea, uri bytea, content_type bytea, memory_buffer_mb int4) returns bytea as '$libdir/pg1c' language c strict;

create or replace function pg1c.http_request(server_1c varchar, urn varchar, content_type varchar default 'application/json') returns text language plpgsql security definer as $body$
declare
  v_server_1c pg1c.server_1c := pg1c.server_1c(server_1c);
  v_auth varchar := ''; 
  v_uri varchar;
  v_response text;
  v_timestamp timestamp := clock_timestamp(); 
begin
  if v_server_1c.auth_expression then
    execute format( $$ select %s||':'||%s $$,
                    case when v_server_1c.user_1c!=''     then v_server_1c.user_1c     else $$ '' $$ end,
                    case when v_server_1c.password_1c!='' then v_server_1c.password_1c else $$ '' $$ end)  
      into v_auth;
  else
    v_auth := case when v_server_1c.user_1c!='' then v_server_1c.user_1c||':'||v_server_1c.password_1c else '' end;
  end if;
  v_uri := replace('/'||v_server_1c.publication||'/odata/standard.odata/'||urn,' ','%20');  
  v_response := convert_from(
    pg1c.http_request(
      host(v_server_1c.web_address)::bytea, 
      v_server_1c.web_port,
      encode(convert_to(v_auth,'UTF-8'),'base64')::bytea, 
      convert_to(v_uri, 'UTF-8'), 
      content_type::bytea,
      v_server_1c.memory_buffer_mb
    ),
    'UTF-8'
  );
  if v_response is null then
    raise exception using
      errcode = 'S8102',
      message = format('PG1C-8102 Внутренняя ошибка (response is null) при выполнении HTTP-запроса к серверу 1С %s по протоколу OData', quote_literal(v_server_1c.id));
  end if;
  if left(v_response,1)!='0' then
    raise exception using errcode = 'S'||substring(v_response,8,4),message = substring(v_response,3);
  end if;
  call pg1c.log_http_request(v_timestamp,server_1c,urn,null);
  return substring(v_response,3); 
exception when others then
  call pg1c.log_http_request(v_timestamp,server_1c,urn,format('[%s] %s',sqlstate,sqlerrm));
  raise exception using errcode=sqlstate,message=sqlerrm;
end; $body$;

do $block$
declare
  v_chars char[] := regexp_split_to_array('абвгдеёжзийклмнопрстуфхцчшщъыьэюяАБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ', '');
  v_newline char := E'\n';
begin
  if upper(current_setting('server_encoding')) in ('UTF-8','UTF8') then  
     create or replace function pg1c.xml_utf8_encode(xml text) returns text language plpgsql as $$ begin return xml; end; $$;
     create or replace function pg1c.xml_utf8_decode(xml text) returns text language plpgsql as $$ begin return xml; end; $$;
     return;
  end if;	
  execute $$  
create or replace function pg1c.xml_utf8_encode(xml text) returns text language plpgsql as $func$
begin
  return $$ || 
    (select string_agg(v_newline||'    replace(', '')||v_newline||'      xml,'||string_agg(v_newline||'      '''||c||''',''#x'||upper(encode(convert_to(c,'UTF-8'),'hex'))||''')', ',') from unnest(v_chars) c)
  || $$;
end; $func$
  $$;
  execute $$  
create or replace function pg1c.xml_utf8_decode(xml text) returns text language plpgsql as $func$
begin
  return $$ || 
    (select string_agg(v_newline||'    replace(', '')||v_newline||'      xml,'||string_agg(v_newline||'      ''#x'||upper(encode(convert_to(c,'UTF-8'),'hex'))||''','''||c||''')', ',') from unnest(v_chars) c)
  || $$;
end; $func$    
  $$; 
end; $block$;

create or replace procedure pg1c.load_metadata_xml(server_1c pg1c.server_1c) language plpgsql as $$
declare
  v_metadata_text text;  
begin
  if to_regtype('pg1c_metadata_xml_server_1c') is not null then
    if exists (select from pg1c_metadata_xml_server_1c s where s.server_1c=load_metadata_xml.server_1c.id) then
      return;
    end if;
  else
    create temporary table pg1c_metadata_xml_server_1c(server_1c varchar primary key) on commit drop;
    create temporary table pg1c_metadata_xml_entity_type on commit drop as select (null::pg1c.metadata_xml_entity_type).* limit 0;
    alter table pg1c_metadata_xml_entity_type add primary key (server_1c, table_1c);
    alter table pg1c_metadata_xml_entity_type alter column name set not null;
    alter table pg1c_metadata_xml_entity_type add unique (name);
    create temporary table pg1c_metadata_xml_enum_type on commit drop as select (null::pg1c.metadata_xml_enum_type).* limit 0;
    alter table pg1c_metadata_xml_enum_type add primary key (server_1c, table_1c);
    alter table pg1c_metadata_xml_enum_type alter column name set not null;
    alter table pg1c_metadata_xml_enum_type add unique (name);
  end if;
  insert into pg1c_metadata_xml_server_1c values (server_1c.id);
  v_metadata_text := pg1c.http_request(server_1c.id, '$metadata', 'application/xml');  
  v_metadata_text := regexp_replace(v_metadata_text, '(.*?)(<edmx:Edmx.*?<Schema.*?>)(.*)', '\1<Schema xmlns:m="void">\3', 'g'); -- remove namespaces
  v_metadata_text := regexp_replace(v_metadata_text, '(.*)(<\/Schema>)(.*)',                '\1</Schema>',                 'g');
  v_metadata_text := pg1c.xml_utf8_encode(v_metadata_text);
  insert into pg1c_metadata_xml_entity_type 
    select server_1c.id,mt.name||'.'||substring(et.name,length(mt.type)+2),et.name,mt.type,mt.name,(rt.name is null),et.properties,et.properties_key,et.properties_navigation
      from
	    (select      
            pg1c.xml_utf8_decode((xpath('/EntityType/@Name', xml_et))[1]::varchar) as name,
            (
              select coalesce(array_agg((pg1c.xml_utf8_decode(name),type)::pg1c.metadata_xml_entity_type_property order by ordinality),array[]::pg1c.metadata_xml_entity_type_property[]) 
  	            from xmltable('/EntityType/Property' passing xml_et columns name text path '@Name', type text path '@Type', ordinality for ordinality)	      
	        ) properties,
            (
              select coalesce(array_agg((pg1c.xml_utf8_decode(name)) order by ordinality),array[]::varchar[]) 
	            from xmltable('/EntityType/Key/PropertyRef' passing xml_et columns name text path '@Name', ordinality for ordinality)	      
            ) properties_key,
            (
              select coalesce(array_agg((pg1c.xml_utf8_decode(name)) order by ordinality),array[]::varchar[]) 
	            from xmltable('/EntityType/NavigationProperty' passing xml_et columns name text path '@Name', ordinality for ordinality)	      
	        ) properties_navigation
          from unnest(xpath('/Schema/EntityType', v_metadata_text::xml)) xml_et) et    
      join pg1c.metadata_type mt on et.name like (mt.type||'\_%') escape '\'
      left join (
        select pg1c.xml_utf8_decode(substring(type,26,length(type)-26-8)) as name
          from xmltable('/Schema/EntityType/Property' passing (v_metadata_text::xml) columns type text path '@Type')
          where type like 'Collection(StandardODATA.%\_RowType)' escape '\'  
      ) rt on rt.name=et.name;
  insert into pg1c_metadata_xml_entity_type 
    select server_1c.id,mt.name||'.'||substring(ct.name,length(mt.type)+2),ct.name,mt.type,mt.name,false,ct.properties,ct.properties_key,ct.properties_navigation
      from
	    (select      
	        pg1c.xml_utf8_decode((xpath('/ComplexType/@Name', xml_ct))[1]::varchar) as name,
            (
              select coalesce(array_agg((pg1c.xml_utf8_decode(name),type)::pg1c.metadata_xml_entity_type_property order by ordinality),array[]::pg1c.metadata_xml_entity_type_property[]) 
  	            from xmltable('/ComplexType/Property' passing xml_ct columns name text path '@Name', type text path '@Type', ordinality for ordinality)	      
	        ) properties,
            (
              select coalesce(array_agg((pg1c.xml_utf8_decode(name)) order by ordinality),array[]::varchar[]) 
	            from xmltable('/ComplexType/Key/PropertyRef' passing xml_ct columns name text path '@Name', ordinality for ordinality)	      
            ) properties_key,
            (
              select coalesce(array_agg((pg1c.xml_utf8_decode(name)) order by ordinality),array[]::varchar[]) 
	            from xmltable('/ComplexType/NavigationProperty' passing xml_ct columns name text path '@Name', ordinality for ordinality)	      
	        ) properties_navigation
          from unnest(xpath('/Schema/ComplexType', v_metadata_text::xml)) xml_ct) ct    
      join pg1c.metadata_type mt on ct.name like (mt.type||'\_%') escape '\';
  insert into pg1c_metadata_xml_enum_type     
    select server_1c.id,'Перечисление.'||name,name,members
      from
	    (select
	        pg1c.xml_utf8_decode((xpath('/EnumType/@Name', xml_et))[1]::varchar) as name,
            (
              select coalesce(array_agg(pg1c.xml_utf8_decode(name::varchar) order by ordinality),array[]::varchar[]) 
	            from unnest(xpath('/EnumType/Member/@Name', xml_et)) with ordinality name
	        ) members
          from unnest(xpath('/Schema/EnumType', v_metadata_text::xml)) xml_et) et
      where et.name not in ('AccountType','AccountingRecordType','AccumulationRecordType','AllowedSign','AllowedLength','DateFractions');
  analyze pg1c_metadata_xml_entity_type;
  analyze pg1c_metadata_xml_enum_type;
  call pg1c.check_updates(server_1c);
end; $$;

create or replace function pg1c.address_pg1c_org() returns bytea as '$libdir/pg1c' language c strict;

create or replace procedure pg1c.check_updates(server_1c pg1c.server_1c) language plpgsql security definer as $$
declare
  v_address bytea;
  v_response text;
  v_version varchar;
begin
  if not server_1c.check_updates or server_1c.check_updates_timestamp is not null and server_1c.check_updates_timestamp+interval '7 days'>clock_timestamp() then
    return;
  end if; 
  update pg1c.server_1c set check_updates_timestamp=clock_timestamp() where id=check_updates.server_1c.id; 
  v_address := pg1c.pg1c.address_pg1c_org();
  if v_address is null then return; end if;
  v_response := convert_from(pg1c.http_request(v_address, 80, ''::bytea, '/files/version.txt#PG1C'::bytea, 'text/html'::bytea, 1), 'UTF-8');
  if left(v_response,1)!='0' then return; end if;
  v_version := substring(v_response,3,4);
  if pg1c.version()<v_version then
    raise notice 'Рекомендуется обновление до версии %', v_version;
  end if;
end; $$;


create or replace function pg1c.metadata_table(server_1c pg1c.server_1c, table_1c varchar, schema name, table_name_pg name) returns pg1c.metadata_table language plpgsql as $$
declare
  v_xml_entity_type pg1c.metadata_xml_entity_type;
  v_xml_entity_type$record_type pg1c.metadata_xml_entity_type;
  v_metadata_table pg1c.metadata_table;
  v_section_metadata pg1c.metadata_table_section;
  v_section_view pg1c.metadata_table;
  v_table pg1c.table;
  v_column pg1c.metadata_column;
  v_names_pg_used name[];
  v_rec record;
begin
  call pg1c.load_metadata_xml(server_1c);
  v_metadata_table.server_1c := server_1c.id;
  v_metadata_table.name_1c := table_1c;
  v_metadata_table.type$enum := table_1c like 'Перечисление.%';
  if not v_metadata_table.type$enum then 
    v_xml_entity_type := (select et from pg1c_metadata_xml_entity_type et where et.server_1c=v_metadata_table.server_1c and et.table_1c=v_metadata_table.name_1c);
    if v_xml_entity_type is null then
      call pg1c.metadata_table_1c_not_found(table_1c);
    end if;
  end if;
  v_table := (select t from pg1c.table t where t.server_1c=v_metadata_table.server_1c and t.name_1c=v_metadata_table.name_1c);
  if v_table is not null then
    v_metadata_table.schema := v_table.schema;
    v_metadata_table.name_pg := v_table.name_pg;
    v_metadata_table.owner := (select relowner::regrole::name from pg_class where oid=(v_metadata_table.schema||'.'||v_metadata_table.name_pg)::regclass::oid); 
  else
    if schema is not null then
      v_metadata_table.schema := schema; 
    else
      execute 'select '||server_1c.schema_expression
        using case when v_metadata_table.type$enum then 'Перечисление' else v_xml_entity_type.type_name end
        into v_metadata_table.schema;
    end if;
    v_metadata_table.name_pg := coalesce(table_name_pg,pg1c.metadata_name_pg((string_to_array(table_1c,'.'))[1], (string_to_array(table_1c,'.'))[2], server_1c.names_pg_short, schema=>v_metadata_table.schema));
    execute 'select quote_ident('||server_1c.owner_expression||')' into v_metadata_table.owner;       
  end if; 
  v_metadata_table.type$reg_recorder := false;
  if v_metadata_table.type$enum then	
    call pg1c.metadata_table$enum(v_metadata_table);
    return v_metadata_table; 
  end if; 
  v_metadata_table.type := v_xml_entity_type.type; 
  if v_metadata_table.type in ('InformationRegister','AccumulationRegister','AccountingRegister','CalculationRegister') then
    v_xml_entity_type$record_type := (select et from pg1c_metadata_xml_entity_type et where et.server_1c=v_metadata_table.server_1c and et.name=v_xml_entity_type.name||'_RecordType');
    if v_xml_entity_type$record_type is not null then      
      v_xml_entity_type := v_xml_entity_type$record_type;
      v_metadata_table.type$reg_recorder := true;
      if not exists (select from unnest(v_xml_entity_type.properties) where name='Recorder') then
        v_xml_entity_type.properties := '{"(Recorder,Edm.String)","(Recorder_Type,Edm.String)"}'::pg1c.metadata_xml_entity_type_property[]||v_xml_entity_type.properties;
      end if; 
    end if; 
  else
    v_metadata_table.type$reg_recorder := false;
  end if;
  v_metadata_table.name_metadata = v_xml_entity_type.name;
  select 
    array_agg(
      (
        p.name,
        p.type,
        case when p.type='Edm.Binary' and p.name like '%\_Base64Data' escape '\' then
          substring(p.name,1,length(p.name)-11)
        when v_metadata_table.type in ('AccountingRegister') and mtc.name_pg is null and coalesce(np.name,p.name) ~ '.[Dr|Cr]$' then
          substring(coalesce(np.name,p.name), '(.*)..')||case when substring(coalesce(np.name,p.name), '.*(..)')='Dr' then 'Дт' else 'Кт' end 
        else
          coalesce(mtc.name_pg,np.name,p.name)
        end,  
        null,
        pg1c.metadata_type_pg(p.type, pt.name is not null),
        null,
        null
      )::pg1c.metadata_column
      order by coalesce(mtc.pos_pg,p.ordinality)
    )  
    into v_metadata_table.columns  
	from unnest(v_xml_entity_type.properties) with ordinality p
	left join unnest(v_xml_entity_type.properties_navigation) np(name) on np.name||'_Key'=p.name
	left join unnest(v_xml_entity_type.properties) pt on pt.name=p.name||'_Type'
	left join pg1c.metadata_type_column mtc on mtc.metadata_type=v_metadata_table.type and mtc.name_metadata=p.name
	where p.name not like '%\_Type' escape '\'
	  and not exists (select from unnest(v_xml_entity_type.properties) b where b.name=p.name||'_Base64Data'); 
  v_names_pg_used := array[]::name[];
  for i in 1..array_length(v_metadata_table.columns,1) loop
    v_column := v_metadata_table.columns[i];
    v_column.name_pg := pg1c.metadata_name_pg(table_1c, v_column.name_pg_src, server_1c.names_pg_short, names_pg_used=>v_names_pg_used);
    v_names_pg_used := v_names_pg_used||v_column.name_pg;
    v_metadata_table.columns[i]:=v_column;   
  end loop;
  select 
    array_agg(c.ordinality)
    into v_metadata_table.columns_pkey  
	from unnest(v_xml_entity_type.properties_key) pk(name)
	join unnest(v_metadata_table.columns) with ordinality c on c.name_1c=pk.name;
  if v_metadata_table.type$reg_recorder and v_metadata_table.columns_pkey[1]!=1 then
    v_metadata_table.columns_pkey := 1||v_metadata_table.columns_pkey;
  end if;
  v_metadata_table.columns_sort := case
    when v_metadata_table.type in ('Constant','InformationRegister','AccumulationRegister','AccountingRegister','CalculationRegister') then
      (select coalesce(array_agg(ordinality order by ordinality),array[]::int[]) from (
        select ordinality 
          from unnest(v_metadata_table.columns) with ordinality c
          where not ordinality=any(v_metadata_table.columns_pkey)
            and type_1c in ('Edm.Guid','Edm.Int16','Edm.Int32','Edm.Int64','Edm.Double','Edm.DateTime')
          order by ordinality
          limit 3) o)
    else
      v_metadata_table.columns_pkey
    end;
  v_metadata_table.column_data_version := (select ordinality from unnest(v_metadata_table.columns) with ordinality where name_1c='DataVersion');
  v_names_pg_used := array[v_metadata_table.name_pg];
  for v_rec in (select ordinality column_idx, row_number() over () section_idx from unnest(v_metadata_table.columns) with ordinality where type_pg='regclass[]') loop
    v_column := v_metadata_table.columns[v_rec.column_idx];
    v_column.section_idx:=v_rec.section_idx;
    v_section_metadata.column_idx := v_rec.column_idx;
    v_section_metadata.name_1c := v_column.name_1c; 
    v_section_metadata.name_pg_view := (select name_pg_view from pg1c.table_section s where s.server_1c=v_metadata_table.server_1c and s.table_1c=v_metadata_table.name_1c and s.name_1c=v_section_metadata.name_1c);
    if v_section_metadata.name_pg_view is null then 
      v_section_metadata.name_pg_view := pg1c.metadata_name_pg(null, v_metadata_table.name_pg||'_'||v_section_metadata.name_1c, server_1c.names_pg_short, schema=>v_metadata_table.schema, names_pg_used=>v_names_pg_used);
      v_names_pg_used := v_names_pg_used||v_section_metadata.name_pg_view;
    end if;
    v_section_view := pg1c.metadata_table(server_1c, table_1c||'_'||v_section_metadata.name_1c, v_metadata_table.schema, null);
    v_section_metadata.columns := v_section_view.columns;
    if v_section_metadata.columns[1].name_1c='LineNumber' then
      v_section_metadata.columns := v_metadata_table.columns[1]||v_section_metadata.columns;
    end if;
    v_metadata_table.sections[v_rec.section_idx] := v_section_metadata;    
    v_metadata_table.columns[v_rec.column_idx]:=v_column;   
  end loop;
  return v_metadata_table; 
end; $$;

create or replace procedure pg1c.metadata_table_1c_not_found(table_1c varchar) language plpgsql as $$
begin
  raise exception using
    errcode = 'S8104',
    message = format('PG1C-8104 Таблица 1С %s не найдена в метаданных', quote_literal(table_1c)),
    hint    = 'К таблице (объекту метаданных) должен быть доступ по протоколу OData, наименование регистрозависимое, тип метаданных указывается в единственном числе';
end; $$;

create or replace function pg1c.metadata_name_pg(group_ varchar, name_1c varchar, name_pg_short boolean, schema name default null, names_pg_used name[] default null) returns name language plpgsql as $$
declare 
  v_relation_name name;
begin
  v_relation_name := (
    with recursive rn as (
      select 1 as i, name_1c name_prev, name_1c as name 
      union 
      select i+1, name, regexp_replace(name, '(.*)([А-Я]|[A-Z]|_[а-я]|_[a-z])([а-я]+|[a-z]+)(.*)', '\1\2\4') from rn
      where i=1 or name_prev!=name
    )   
    select name
      from rn
      where
        (schema is null or not exists (select from pg_class,pg_namespace where relnamespace=pg_namespace.oid and nspname=schema and relname=(parse_ident(rn.name::name))[1]))
        and
        (names_pg_used is null or not rn.name::name=any(names_pg_used))
        and
        (not name_pg_short or name=name::name::varchar) 
      order by rn.i
      limit 1
  );  
  if v_relation_name is null then 
    raise exception using
      errcode = 'S8106',
      message = format('PG1C-8106 Невозможно подобрать наименование в PostgreSQL для %s', quote_literal(coalesce(group_||'.','')||name_1c)),
      hint    = 'Для таблицы название можно указать явно при вызове функции pg1c.create_table';
  end if;
  return v_relation_name; 
end; $$;


create or replace function pg1c.table_column_options(metadata_table pg1c.metadata_table, column_idx int) returns varchar language plpgsql as $$
declare
  v_column pg1c.metadata_column := metadata_table.columns[column_idx];
  v_column_pkey boolean := column_idx=any(metadata_table.columns_pkey);
begin
  return case	
    when metadata_table.type$enum and v_column.name_pg='Порядок' then ' not null unique' 
    --
    when v_column.type_pg = 'pg1c.value_any' then ' check (substring(('||v_column.name_pg||').type,1,4)!=''Edm.'' and substring(('||v_column.name_pg||').type,1,14)!=''StandardODATA.'')'
    --
    when v_column.type_pg = 'uuid'      then        case when v_column_pkey then '' else ' check ('||v_column.name_pg||'!=''00000000-0000-0000-0000-000000000000''::uuid)' end
    when v_column.type_pg = 'timestamp' then '(0)'||case when v_column_pkey then '' else ' check ('||v_column.name_pg||'!=''0001-01-01T00:00:00''::timestamp)' end
    when v_column.type_pg = 'bytea'     then        case when v_column_pkey then '' else ' check ('||v_column.name_pg||'!=''''::bytea)' end    
    --
    else ' not null'
  end;  
end; $$;

create or replace function pg1c.json_to_column(alias varchar, name_1c varchar, type_1c varchar, type_pg name, nullable boolean) returns varchar language plpgsql as $$
declare
  v_value       varchar := alias||'.value->'||quote_literal(name_1c);
  v_value_text  varchar := alias||'.value->>'||quote_literal(name_1c);
  v_value_type  varchar := alias||'.value->>'||quote_literal(name_1c||'_Type'); 
begin
  return case
    when type_pg='pg1c.value_any' then  
  	  'pg1c.value_any('||v_value_text||','||v_value_type||')'
    when type_pg='uuid' and nullable then
      'case when '||v_value_text||'=''00000000-0000-0000-0000-000000000000'' then null else '||v_value_text||' end::'||type_pg
    when type_pg='timestamp' and nullable then
      'case when '||v_value_text||'=''0001-01-01T00:00:00'' then null else '||v_value_text||' end::'||type_pg
    when type_pg in ('int2','int4','int8','numeric') then      
      'coalesce(('||v_value_text||')::'||type_pg||',0)'
    when type_pg='bool' then      
      'coalesce(('||v_value_text||')::bool,false)'
    when type_pg='text' then      
      'coalesce('||v_value_text||','''')'
    when type_pg='text' then      
      'coalesce('||v_value_text||','''')'
    when type_pg='bytea' then
      'decode('||case when nullable then 'case when '||v_value_text||'='''' then null else '||v_value_text||' end' else v_value_text end||',''base64'')'
    when type_1c='StandardODATA.TypeDescription' then      
      '(select coalesce(array_agg(pg1c.type_ref_to_pg(value)),array[]::'||type_pg||') from jsonb_array_elements_text('||v_value||'->''Types''))'      
    else
      '('||v_value_text||')::'||type_pg
  end;
end; $$;

create or replace function pg1c.json_to_columns(metadata_table pg1c.metadata_table, indent varchar) returns text language plpgsql as $body$
declare
  v_section pg1c.metadata_table_section;
  v_section_view varchar;
  v_column record;
  v_columns text;
  v_newline char := E'\n';
begin
  for v_column in (select * from unnest(metadata_table.columns) with ordinality col order by pos_pg) loop
    v_columns := case when v_columns is not null then v_columns||','||v_newline else '' end||indent;    
    if v_column.section_idx is null then
      v_columns := v_columns||pg1c.json_to_column('t',v_column.name_1c,v_column.type_1c,v_column.type_pg,not v_column.ordinality=any(metadata_table.columns_pkey));
    else
      v_section := metadata_table.sections[v_column.section_idx];
      v_section_view := metadata_table.schema||'.'||v_section.name_pg_view;
      v_columns := v_columns||
        '(select coalesce('||v_newline||
        indent||'    array_agg(('||v_newline||
        indent||'      '||pg1c.columns_to_text(v_section.columns,null,null,$$ pg1c.json_to_column(case when ordinality=1 then 't' else 's' end,col.name_1c,col.type_1c,col.type_pg,false) $$,','||v_newline||indent||'      ')||v_newline||
        indent||'    )::'||v_section_view||'),'||v_newline||
        indent||'    array[]::'||v_section_view||'[])'||v_newline||
        indent||'  from jsonb_array_elements(value->'||quote_literal(v_column.name_1c)||') s'||v_newline||
        indent||')';       
    end if;
  end loop;
  return v_columns;
end; $body$;

create or replace function pg1c.columns_to_text(columns pg1c.metadata_column[], columns_include int[] default null, columns_exclude int[] default null, expression text default 'col.name_pg', delimiter varchar default ',') returns varchar language plpgsql as $$
declare
  v_text text;
begin 
  execute format(
    'select coalesce(string_agg(%s, ''%s'' order by pos_pg,ordinality),'''')'
    '  from unnest($1) with ordinality col'
    '  where ($2 is null or ordinality=any($2)) and ($3 is null or not ordinality=any($3))',
    expression,
    delimiter
  )
    into v_text
    using columns,columns_include,columns_exclude;	
  return v_text;  
end; $$;

create or replace function pg1c.relation_columns(schema name, relation_name name) returns table(pos_pg int, name_pg name, type_pg varchar) language sql as $$
  select (row_number() over (order by attnum))::int pos_pg, a.attname name_pg,case when tn.nspname='pg_catalog' then '' else tn.nspname||'.' end||coalesce(ta.typname||'[]',t.typname) type_pg  
    from pg_attribute a 
    join pg_type t on t.oid=a.atttypid
    left join pg_type ta on t.typcategory='A' and ta.oid=t.typelem
    join pg_namespace tn on tn.oid=t.typnamespace 
    where a.attrelid=(schema||'.'||relation_name)::regclass::oid and a.attnum>0 and not a.attisdropped
    order by 1
$$;

create or replace function pg1c.metadata_columns_pos_pg(schema name, relation_name name, columns pg1c.metadata_column[]) returns pg1c.metadata_column[] language plpgsql as $$
declare
  v_column pg1c.metadata_column;
  v_columns pg1c.metadata_column[] := columns;
  v_column_idx int;
  v_rec record;
begin
  for v_rec in (	
    select c.ordinality idx,rc.pos_pg 
      from unnest(v_columns) with ordinality c
      join pg1c.relation_columns(schema,relation_name) rc on rc.name_pg=(parse_ident(c.name_pg))[1]
  ) loop
    v_column := v_columns[v_rec.idx];
    v_column.pos_pg := v_rec.pos_pg;
    v_columns[v_rec.idx] := v_column;
  end loop;
  return v_columns; 
end; $$;

create or replace procedure pg1c.refresh_data(table_1c varchar, server_1c varchar default 'DEFAULT') language plpgsql as $body$
declare
  v_table pg1c.table := pg1c.table(table_1c,server_1c);
begin	
  execute format('select count(1) from %s.%s()',v_table.schema,v_table.name_pg);
end; $body$;

create or replace procedure pg1c.check_metadata_access(table_ pg1c.table) language plpgsql as $$
declare 
  v_owner name;
begin
  v_owner := (
    select r.rolname
      from pg_class c 
      join pg_roles r on r.oid=c.relowner
      where c.oid=(table_.schema||'.'||table_.name_pg)::regclass::oid
  );
  if not pg_has_role(session_user, v_owner, 'MEMBER') then 
    raise exception using
      errcode = 'S8105',
      message = format('PG1C-8105 Запрещен доступ к изменению метаданных таблицы 1C %s (владелец %s)', quote_literal(table_.name_1c), quote_literal(v_owner)),
      hint    = format('Выдайте роль пользователю %s или переназначить владельца таблицы %s',
                       quote_literal('grant '||quote_ident(v_owner)||' to '||quote_ident(session_user)||';'), quote_literal(table_.schema||'.'||table_.name_pg));
  end if;
end; $$;

create or replace procedure pg1c.create_table_section(metadata_table pg1c.metadata_table, section_idx int) language plpgsql as $body$
declare
  v_section pg1c.metadata_table_section := metadata_table.sections[section_idx];
  v_section_column name := metadata_table.columns[v_section.column_idx].name_pg; 
  v_section_view varchar := metadata_table.schema||'.'||v_section.name_pg_view;  
  v_sql text;
  v_newline char := E'\n';
begin
  call pg1c.execute_metadata_sql(metadata_table,
    'create view '||v_section_view||' as'||
    '  select '||pg1c.columns_to_text(v_section.columns, expression => $$ 'null::'||col.type_pg||' as '||col.name_pg $$)
  );  
  call pg1c.execute_metadata_sql(metadata_table,
    'alter view '||v_section_view||' owner to '||metadata_table.owner
  );
  call pg1c.execute_metadata_sql(metadata_table,
    'alter table '||metadata_table.schema||'.'||metadata_table.name_pg||' alter column '||v_section_column||' type '||v_section_view||'[] using null'
  );  
  v_sql :=   
    'create or replace view '||v_section_view||' as'||v_newline||
    '  select '||
    (select string_agg(case when ordinality=1 then 't' else 's' end||'.'||c.name_pg, ',' order by ordinality)
      from unnest(v_section.columns) with ordinality c)||v_newline||    
    '    from '||metadata_table.schema||'.'||metadata_table.name_pg||' t'||v_newline||
    '    cross join unnest(t.'||metadata_table.columns[v_section.column_idx].name_pg||') s';
  call pg1c.execute_metadata_sql(metadata_table,v_sql);  
  call pg1c.execute_metadata_sql(metadata_table,
    'insert into pg1c.table_section(server_1c,table_1c,name_1c,name_pg_column,name_pg_view)'||
    ' values ('||quote_literal(metadata_table.server_1c)||','||quote_literal(metadata_table.name_1c)||','||quote_literal(v_section.name_1c)||','||quote_literal(v_section_column)||','||quote_literal(v_section.name_pg_view)||')'
  ); 
end; $body$;

create or replace procedure pg1c.drop_table_section(table_ pg1c.table, name_1c varchar) language plpgsql as $$
declare
  v_section pg1c.table_section := (select ts from pg1c.table_section ts where ts.server_1c=table_.server_1c and ts.table_1c=table_.name_1c and ts.name_1c=drop_table_section.name_1c);	
  v_section_view varchar := table_.schema||'.'||v_section.name_pg_view;
  v_sql text;
begin
  v_sql :=	
    'create or replace view '||v_section_view||' as select '||
    (select string_agg('null::'||type_pg||' as '||name_pg, ',' order by pos_pg) from pg1c.relation_columns(table_.schema,v_section.name_pg_view));
  call pg1c.execute_metadata_sql(table_.server_1c,table_.name_1c,v_sql);
  call pg1c.execute_metadata_sql(table_.server_1c,table_.name_1c,'alter table '||table_.schema||'.'||table_.name_pg||' drop column '||v_section.name_pg_column);
  call pg1c.execute_metadata_sql(table_.server_1c,table_.name_1c,'drop view '||v_section_view);
  call pg1c.execute_metadata_sql(table_.server_1c,table_.name_1c, 
    'delete from pg1c.table_section where server_1c='||quote_literal(table_.server_1c)||' and table_1c='||quote_literal(table_.name_1c)||' and name_1c='||quote_literal(name_1c)
  ); 
end; $$;

create or replace procedure pg1c.drop_table(table_1c varchar, server_1c varchar default 'DEFAULT') security definer language plpgsql as $$
declare
  v_table pg1c.table := (select t from pg1c.table t where t.server_1c=drop_table.server_1c and t.name_1c=table_1c);
  v_section pg1c.table_section;
begin
  if v_table is null then
    raise notice 'Таблица 1C % не существует в PostgreSQL, удаление игнорируется', quote_literal(table_1c);
    return; 
  end if;
  call pg1c.check_metadata_access(v_table);
  for v_section in (select * from pg1c.table_section ts where ts.server_1c=drop_table.server_1c and ts.table_1c=v_table.name_1c order by name_1c) loop
    call pg1c.drop_table_section(v_table, v_section.name_1c);
  end loop;
  call pg1c.execute_metadata_sql(server_1c,table_1c,'drop function if exists '||v_table.schema||'.'||v_table.name_pg||'()');
  call pg1c.execute_metadata_sql(server_1c,table_1c,'drop function if exists '||v_table.schema||'.'||v_table.name_pg);
  call pg1c.execute_metadata_sql(server_1c,table_1c,'drop table if exists '||v_table.schema||'.'||v_table.name_pg);
  call pg1c.execute_metadata_sql(server_1c,table_1c,'delete from pg1c.table where server_1c='||quote_literal(server_1c)||' and name_1c='||quote_literal(table_1c)); 
end; $$;

create or replace function pg1c.create_table_only(table_1c varchar, server_1c varchar default 'DEFAULT', schema name default null, table_name_pg name default null) returns varchar language plpgsql security definer as $body$
declare
  v_server_1c pg1c.server_1c := pg1c.server_1c(server_1c);
  v_metadata_table pg1c.metadata_table;
  v_table_pg varchar;
  v_sql text;
  v_newline char := E'\n';
begin
  v_table_pg := (select t.schema||'.'||t.name_pg from pg1c.table t where t.server_1c=v_server_1c.id and t.name_1c=table_1c);
  if v_table_pg is not null then
    raise notice 'Таблица 1C % уже существует в PostgreSQL, создание игнорируется', quote_literal(table_1c);
    return v_table_pg;
  end if;
  v_metadata_table := pg1c.metadata_table(v_server_1c,table_1c,schema,table_name_pg);
  if not exists (select from pg_namespace where nspname=(parse_ident(v_metadata_table.schema))[1]) then
    call pg1c.execute_metadata_sql(v_metadata_table,'create schema '||v_metadata_table.schema||' authorization '||v_metadata_table.owner);
  end if;
  v_table_pg := v_metadata_table.schema||'.'||v_metadata_table.name_pg;
  v_sql := 
    'create table '||v_table_pg||' ('||v_newline||
    pg1c.columns_to_text(v_metadata_table.columns, null, null, 
      $$ 
        '  '||col.name_pg||' '||col.type_pg||pg1c.table_column_options( $$||quote_literal(v_metadata_table::text)||$$ ,col.ordinality::int)||E',\n' 
      $$,
      '')||
    '  primary key ('||pg1c.columns_to_text(v_metadata_table.columns,v_metadata_table.columns_pkey)||')'||v_newline||
    ')';
  call pg1c.execute_metadata_sql(v_metadata_table,v_sql);
  call pg1c.execute_metadata_sql(v_metadata_table,'alter table '||v_metadata_table.schema||'.'||v_metadata_table.name_pg||' owner to '||v_metadata_table.owner);
  call pg1c.execute_metadata_sql(v_metadata_table,
    'insert into pg1c.table(server_1c,name_1c,metadata_type,schema,name_pg,refresh_metadata_timestamp)'||
    ' values('||quote_literal(server_1c)||','||quote_literal(table_1c)||','||quote_literal(v_metadata_table.type)||','||quote_literal(v_metadata_table.schema)||','||quote_literal(v_metadata_table.name_pg)||',clock_timestamp())'
  );  
  for i in 1..coalesce(array_length(v_metadata_table.sections,1),0) loop
    call pg1c.create_table_section(v_metadata_table, i);
  end loop;
  call pg1c.create_functions(v_metadata_table);
  return v_table_pg;
end; $body$;

create or replace function pg1c.create_table(table_1c varchar, server_1c varchar default 'DEFAULT', schema name default null, table_name_pg name default null) returns varchar language plpgsql as $$
declare
  v_table_pg varchar;
begin
  v_table_pg := pg1c.create_table_only(table_1c, server_1c, schema, table_name_pg);
  if (pg1c.table(table_1c,server_1c)).metadata_type!='Enumeration' then  
    call pg1c.refresh_data(table_1c, server_1c); 
  end if;
  return v_table_pg;
end; $$;


create or replace procedure pg1c.create_functions(metadata_table pg1c.metadata_table) language plpgsql as $body$
declare
  v_section pg1c.metadata_table_section; 
  v_pkey varchar;
  v_new boolean;
  v_sql text;
  v_newline char := E'\n';  
begin
  if metadata_table.type$enum then
    call pg1c.create_functions$enum(metadata_table);
    return;
  end if;
  v_pkey := (select conname from pg_constraint where conrelid=(metadata_table.schema||'.'||metadata_table.name_pg)::regclass::oid and contype='p');
  v_new := not exists (select from pg_proc p where pronamespace=metadata_table.schema::regnamespace::oid and proname=(parse_ident(metadata_table.name_pg))[1]);    
  metadata_table.columns := pg1c.metadata_columns_pos_pg(metadata_table.schema,metadata_table.name_pg, metadata_table.columns);
  for i in 1..coalesce(array_length(metadata_table.sections,1),0) loop
    v_section := metadata_table.sections[i];
    v_section.columns := pg1c.metadata_columns_pos_pg(metadata_table.schema,v_section.name_pg_view, v_section.columns);
    metadata_table.sections[i] := v_section;
  end loop;
  v_sql := 
    'create or replace function '||metadata_table.schema||'.'||metadata_table.name_pg||'() returns setof '||metadata_table.schema||'.'||metadata_table.name_pg||' security definer language plpgsql as $$'||v_newline||
    'declare'||v_newline||
    '  v_fetch_size int := (select fetch_size from pg1c.table where server_1c='||quote_literal(metadata_table.server_1c)||' and name_1c='||quote_literal(metadata_table.name_1c)||');'||v_newline||
    '  v_fetch_count int;'||v_newline||
    '  v_skip int := 0;'||v_newline||
    '  v_response text;'||v_newline||
    '  v_value jsonb;'||v_newline||
    '  v_refresh_data_timestamp timestamp;'||v_newline||
    'begin '||v_newline||
    '  create temporary table pg1c_temp_buffer as select * from '||metadata_table.schema||'.'||metadata_table.name_pg||' limit 0;'||v_newline||
    '  alter table pg1c_temp_buffer add primary key('||pg1c.columns_to_text(metadata_table.columns,metadata_table.columns_pkey)||');'||v_newline||
    '  lock table '||metadata_table.schema||'.'||metadata_table.name_pg||' in share row exclusive mode;'||v_newline||
    '  v_refresh_data_timestamp := clock_timestamp();'||v_newline||   
    '  --'||v_newline||
    '  loop'||v_newline||
    '    v_response := pg1c.http_request('||quote_literal(metadata_table.server_1c)||','''||metadata_table.name_metadata||'?'||
    case when coalesce(array_length(metadata_table.columns_sort,1),0)!=0 then     
      '$orderby='||pg1c.columns_to_text(metadata_table.columns,metadata_table.columns_sort,expression => $$ col.name_1c $$)||'&'
    else
      ''
    end||    
    '$skip=''||v_skip||''&$top=''||v_fetch_size);'||v_newline||
    '    v_value := v_response::jsonb->''value'';'||v_newline||
    '    with data as ('||v_newline||
    '      select'||v_newline||
    pg1c.json_to_columns(metadata_table, '          ')||v_newline||
    '        from jsonb_array_elements(v_value) t'||v_newline||
    '    ),'||v_newline||
    '    inserted as ('||v_newline||
    '      insert into pg1c_temp_buffer'||v_newline||
    '        select * from data'||v_newline||
    '        on conflict do nothing'||v_newline||
    '    )'||v_newline||
    '    select count(1) into v_fetch_count from data;'||v_newline||
    '    exit when v_fetch_count<v_fetch_size;'||v_newline||
    '    v_skip := v_skip + (v_fetch_size+1)/2;'||v_newline||    
    '  end loop;'||v_newline||
    '  --'||v_newline||
    '  perform set_config(''pg1c.refresh_data'', true::varchar, true);'||v_newline;
  if array_length(metadata_table.columns,1)>array_length(metadata_table.columns_pkey,1) then 
    v_sql := v_sql||  
      '  update '||metadata_table.schema||'.'||metadata_table.name_pg||' tu '||v_newline||
      '    set ('||pg1c.columns_to_text(metadata_table.columns,null,metadata_table.columns_pkey)||')'||v_newline||
      '      = row('||pg1c.columns_to_text(metadata_table.columns,null,metadata_table.columns_pkey,$$ 'b.'||col.name_pg $$)||')'||v_newline||    
      '    from '||metadata_table.schema||'.'||metadata_table.name_pg||' t'||v_newline||
      '    join pg1c_temp_buffer b on '||pg1c.columns_to_text(metadata_table.columns,metadata_table.columns_pkey,null,$$ 'b.'||col.name_pg||'=t.'||col.name_pg||' and ' $$, '')||
      case when metadata_table.column_data_version is not null then
        'b.'||metadata_table.columns[metadata_table.column_data_version].name_pg||'!=t.'||metadata_table.columns[metadata_table.column_data_version].name_pg
      else
        pg1c.columns_to_text(
          metadata_table.columns,
          null,
          metadata_table.columns_pkey,
          $$ 't.'||col.name_pg||' is not null and b.'||col.name_pg||' is null or t.'||col.name_pg||' is null and b.'||col.name_pg||' is not null or t.'||col.name_pg||'!=b.'||col.name_pg $$,
          ' or'||v_newline||'            '
        )
      end||v_newline||
      '    where '||pg1c.columns_to_text(metadata_table.columns,metadata_table.columns_pkey,null,$$ 'tu.'||col.name_pg||'=t.'||col.name_pg $$, ' and ')||';'||v_newline;
  end if;   
  v_sql := v_sql||   
    '  insert into '||metadata_table.schema||'.'||metadata_table.name_pg||v_newline||
    '    select b.* from pg1c_temp_buffer b'||v_newline||
    '      left join '||metadata_table.schema||'.'||metadata_table.name_pg||' t on '||pg1c.columns_to_text(metadata_table.columns,metadata_table.columns_pkey,null,$$ 't.'||col.name_pg||'=b.'||col.name_pg $$, ' and ')||v_newline||
    '      where t.'||metadata_table.columns[metadata_table.columns_pkey[1]].name_pg||' is null;'||v_newline||    
    '  delete from '||metadata_table.schema||'.'||metadata_table.name_pg||v_newline||
    '    using '||metadata_table.schema||'.'||metadata_table.name_pg||' t'||v_newline||    
    '    left join pg1c_temp_buffer b on '||pg1c.columns_to_text(metadata_table.columns,metadata_table.columns_pkey,null,$$ 'b.'||col.name_pg||'=t.'||col.name_pg $$, ' and ')||v_newline||
    '    where b.'||metadata_table.columns[metadata_table.columns_pkey[1]].name_pg||' is null;'||v_newline||
    '  perform set_config(''pg1c.refresh_data'', false::varchar, true);'||v_newline||
    '  --'||v_newline||
    '  drop table pg1c_temp_buffer;'||v_newline||
    '  update pg1c.table set'||v_newline||
    '      row_count              = (select count(1) from '||metadata_table.schema||'.'||metadata_table.name_pg||'),'||v_newline||   
    '      refresh_data_timestamp = v_refresh_data_timestamp,'||v_newline||
    '      refresh_data_duration  = clock_timestamp()-v_refresh_data_timestamp'||v_newline||
    '    where server_1c='||quote_literal(metadata_table.server_1c)||' and name_1c='||quote_literal(metadata_table.name_1c)||';'||v_newline||    
    '  return query select * from '||metadata_table.schema||'.'||metadata_table.name_pg||';'||v_newline||
    'end;'||v_newline||
    '$$';
  call pg1c.execute_metadata_sql(metadata_table,v_sql);
  --
  v_sql := 
    'create or replace function '||metadata_table.schema||'.'||metadata_table.name_pg||'('||
    pg1c.columns_to_text(metadata_table.columns,metadata_table.columns_pkey,null,$$ col.name_pg||' '||col.type_pg $$)||
    ') returns '||metadata_table.schema||'.'||metadata_table.name_pg||' security definer language plpgsql as $$'||v_newline||
    'declare'||v_newline||
    '  v_response text;'||v_newline||
    '  v_value jsonb;'||v_newline||
    '  v_record '||metadata_table.schema||'.'||metadata_table.name_pg||';'||v_newline||   
    'begin'||v_newline||
    '  lock table '||metadata_table.schema||'.'||metadata_table.name_pg||' in share mode;'||v_newline||    
    '  perform pg_advisory_xact_lock('||quote_literal(metadata_table.schema||'.'||metadata_table.name_pg)||'::regclass::oid::int,'||
    'hashtext('||pg1c.columns_to_text(metadata_table.columns,metadata_table.columns_pkey,null,$$ col.name_pg||'::text' $$,'||'''',''''||')||'));'||v_newline||    
    '  v_response := pg1c.http_request('||quote_literal(metadata_table.server_1c)||','''||metadata_table.name_metadata||
    case when metadata_table.type!='Constant' then
      '?$filter='||pg1c.columns_to_text(metadata_table.columns,metadata_table.columns_pkey,null,$$ 
        col.name_1c||' eq '||
        case when col.type_pg='uuid'      then 'guid''||quote_literal('||col.name_pg||')'
             when col.type_pg='text'      then '''||quote_literal('||col.name_pg||')'
             when col.type_pg='timestamp' then 'datetime''||quote_literal(to_char('||col.name_pg||',''yyyy-mm-ddThh24:mi:ss''))'
        else '''||'||col.name_pg          
        end
      $$, '||'''' and ')
    else
      ''''
    end||');'||v_newline||
    '  v_value := v_response::jsonb->''value'';'||v_newline||
    '  v_record := ('||v_newline||
    '    select ('||v_newline||
    pg1c.json_to_columns(metadata_table, '          ')||v_newline||
    '        )'||v_newline||    
    '      from jsonb_array_elements(v_value) t);'||v_newline||
    '  perform set_config(''pg1c.refresh_data'', true::varchar, true);'||v_newline||
    '  if v_record.'||metadata_table.columns[metadata_table.columns_pkey[1]].name_pg||' is not null then'||v_newline||
    '    insert into '||metadata_table.schema||'.'||metadata_table.name_pg||' values(v_record.*)'||v_newline||
    '      on conflict on constraint '||v_pkey||' do'||v_newline|| 
  case when array_length(metadata_table.columns,1)>array_length(metadata_table.columns_pkey,1) then    
    '        update set ('||pg1c.columns_to_text(metadata_table.columns,null,metadata_table.columns_pkey)||')'||v_newline||
    '          = row('||pg1c.columns_to_text(metadata_table.columns,null,metadata_table.columns_pkey,$$ 'v_record.'||col.name_pg $$)||')'
  else  
    '        nothing'
  end||';'||v_newline||
    '  else'||v_newline||
    '    delete from '||metadata_table.schema||'.'||metadata_table.name_pg||' t'||v_newline||
    '      where '||pg1c.columns_to_text(metadata_table.columns,metadata_table.columns_pkey,null, $$ 't.'||col.name_pg||'='|| $$||quote_literal(metadata_table.name_pg)||$$ ||'.'||col.name_pg $$ , ' and ')||';'||v_newline||  
    '  end if;'||v_newline||
    '  perform set_config(''pg1c.refresh_data'', false::varchar, true);'||v_newline||
    '  return v_record;'||v_newline||
    'end;'||v_newline||
    '$$';
  call pg1c.execute_metadata_sql(metadata_table, v_sql);
  if v_new then 
    call pg1c.set_function_access(metadata_table,'');
    call pg1c.set_function_access(metadata_table,pg1c.columns_to_text(metadata_table.columns,metadata_table.columns_pkey,null,$$ col.type_pg $$));  
    call pg1c.execute_metadata_sql(metadata_table,'create trigger exception_dml before insert or update or delete or truncate on '||metadata_table.schema||'.'||metadata_table.name_pg||' execute function pg1c.exception_dml()'); 
  end if;
end; $body$;

create or replace procedure pg1c.set_function_access(metadata_table pg1c.metadata_table, params varchar) language plpgsql as $$
begin
  call pg1c.execute_metadata_sql(metadata_table,'alter function '||metadata_table.schema||'.'||metadata_table.name_pg||'('||params||') owner to '||metadata_table.owner);
  call pg1c.execute_metadata_sql(metadata_table,'revoke execute on function '||metadata_table.schema||'.'||metadata_table.name_pg||'('||params||') from public');
end; $$;

create or replace function pg1c.exception_dml() returns trigger language plpgsql as $$
begin
  if current_setting('pg1c.refresh_data',true)=true::varchar then
    return null;
  end if;   
  raise exception using
    errcode = 'S8110',
    message = 'PG1C-8110 Изменение таблицы 1С не поддерживается';
end; $$;

select current_setting('pghist.transaction_id', true)::boolean;

create or replace procedure pg1c.refresh_metadata_only(table_1c varchar, server_1c varchar default 'DEFAULT', inout refresh_data boolean default false) security definer language plpgsql as $$
declare
  v_server_1c pg1c.server_1c := pg1c.server_1c(server_1c);
  v_table pg1c.table := pg1c.table(table_1c,server_1c);
  v_metadata_table pg1c.metadata_table;
  v_metadata_section pg1c.metadata_table_section;
  v_metadata_column pg1c.metadata_column; 
  v_columns_add int[];
  v_columns_drop name[];   
  v_sql_prefix text := 'alter table '||v_table.schema||'.'||v_table.name_pg||' ';  
  v_section_rec record;
  v_refresh_metadata boolean := false;
begin	
  call pg1c.check_metadata_access(v_table);
  call pg1c.execute_metadata_sql(server_1c,table_1c,
    'update pg1c.table set refresh_metadata_timestamp=clock_timestamp() where server_1c='||quote_literal(server_1c)||' and name_1c='||quote_literal(table_1c)
  );
  v_metadata_table := pg1c.metadata_table(v_server_1c, v_table.name_1c, v_table.schema, v_table.name_pg);
  if v_metadata_table.type$enum then
    call pg1c.refresh_metadata_only$enum(v_metadata_table);
    return;
  end if;	
  select array_agg(mc.ordinality order by mc.ordinality) filter (where mc.ordinality is not null),
         array_agg(rc.name_pg order by rc.pos_pg) filter (where rc.name_pg is not null)  
    into v_columns_add,v_columns_drop
    from unnest(v_metadata_table.columns) with ordinality mc
    full join pg1c.relation_columns(v_metadata_table.schema,v_metadata_table.name_pg) rc on rc.name_pg=(parse_ident(mc.name_pg))[1]
    where (rc.name_pg is null and mc.section_idx is null)
       or (rc.name_pg not in (select (parse_ident(name_pg_column))[1] from pg1c.table_section ts where ts.server_1c=v_server_1c.id and ts.table_1c=v_table.name_1c) and (mc.type_pg is null or mc.type_pg!=rc.type_pg));
  for i in 1..coalesce(array_length(v_columns_drop,1),0) loop
    call pg1c.execute_metadata_sql(v_server_1c.id,v_table.name_1c,v_sql_prefix||'drop column '||v_columns_drop[i]);
    v_refresh_metadata := true;
  end loop;
  for i in 1..coalesce(array_length(v_columns_add,1),0) loop
    v_metadata_column := v_metadata_table.columns[v_columns_add[i]];
    perform set_config('pg1c.refresh_data', true::varchar, true);    
    call pg1c.execute_metadata_sql(v_metadata_table,'truncate '||v_table.schema||'.'||v_table.name_pg);
    perform set_config('pg1c.refresh_data', false::varchar, true);   
    call pg1c.execute_metadata_sql(v_metadata_table,v_sql_prefix||'add column '||v_metadata_column.name_pg||' '||v_metadata_column.type_pg||pg1c.table_column_options(v_metadata_table,v_columns_add[i]));
    v_refresh_metadata := true;   
    refresh_data := true;
  end loop;
  for v_section_rec in (
    select m.ordinality::int idx_add, e.name_1c name_1c_drop
      from unnest(v_metadata_table.sections) with ordinality m
      full join (select * from pg1c.table_section e where e.server_1c=v_server_1c.id and e.table_1c=v_table.name_1c) e on e.name_1c=m.name_1c
  ) loop
    v_metadata_section := v_metadata_table.sections[v_section_rec.idx_add];
    v_metadata_column := v_metadata_table.columns[v_metadata_section.column_idx];
    if v_section_rec.idx_add is not null and v_section_rec.name_1c_drop is not null and not exists ( 
      select   
        from unnest(v_metadata_section.columns) c
        full join pg1c.relation_columns(v_metadata_table.schema,v_metadata_section.name_pg_view) rc on rc.name_pg=(parse_ident(c.name_pg))[1] 
        where rc.name_pg is null or c.name_pg is null or rc.type_pg!=c.type_pg
    ) then
      continue;
    end if;
    if v_section_rec.name_1c_drop is not null then
      call pg1c.drop_table_section(v_table, v_section_rec.name_1c_drop);
      v_refresh_metadata := true;     
    end if;
    if v_section_rec.idx_add is not null then
      perform set_config('pg1c.refresh_data', true::varchar, true);
      call pg1c.execute_metadata_sql(v_metadata_table,'truncate '||v_table.schema||'.'||v_table.name_pg);
      perform set_config('pg1c.refresh_data', false::varchar, true);
      call pg1c.execute_metadata_sql(v_metadata_table,v_sql_prefix||'add column '||v_metadata_column.name_pg||' '||v_metadata_column.type_pg||pg1c.table_column_options(v_metadata_table,v_metadata_section.column_idx));
      call pg1c.create_table_section(v_metadata_table, v_section_rec.idx_add);
      v_refresh_metadata := true;     
      refresh_data := true;
    end if;
  end loop;
  if v_refresh_metadata then
    call pg1c.create_functions(v_metadata_table); 
  end if;
end; $$;

create or replace procedure pg1c.refresh_metadata(table_1c varchar, server_1c varchar default 'DEFAULT', refresh_data boolean default false) security definer language plpgsql as $$
begin
  call pg1c.refresh_metadata_only(table_1c, server_1c, refresh_data);	
  if refresh_data then
    call pg1c.refresh_data(table_1c, server_1c);
  end if; 
end; $$;


create or replace procedure pg1c.metadata_table$enum(inout metadata_table pg1c.metadata_table) language plpgsql as $$
declare
  v_enum_xml xml;
  v_metadata_table pg1c.metadata_table;
  v_column pg1c.metadata_column;
  v_xml_enum_type pg1c.metadata_xml_enum_type;
begin	
  v_xml_enum_type := (select et from pg1c_metadata_xml_enum_type et where et.server_1c=metadata_table.server_1c and et.table_1c=metadata_table.name_1c); 
  if v_xml_enum_type is null then
    call pg1c.metadata_table_1c_not_found(table_1c);
  end if;
  metadata_table.type := 'Enumeration';
  v_column.name_1c := 'Ссылка'; 
  v_column.name_pg := 'Ссылка';
  v_column.type_pg := 'text';
  metadata_table.columns[1] := v_column;
  v_column.name_1c := 'Порядок'; 
  v_column.name_pg := 'Порядок';
  v_column.type_pg := 'int8';
  metadata_table.columns[2] := v_column; 
  metadata_table.columns_pkey := array[1];
end; $$;

create or replace procedure pg1c.refresh_metadata_only$enum(metadata_table pg1c.metadata_table) language plpgsql as $$
declare 
  v_xml_enum_type pg1c.metadata_xml_enum_type;
  v_newline char := E'\n'; 
begin	
  v_xml_enum_type := (select et from pg1c_metadata_xml_enum_type et where et.server_1c=metadata_table.server_1c and et.table_1c=metadata_table.name_1c); 
  if v_xml_enum_type is null then
    call pg1c.metadata_table_1c_not_found(table_1c);
  end if;
  call pg1c.execute_metadata_sql(metadata_table,
    'lock table '||metadata_table.schema||'.'||metadata_table.name_pg||' in share row exclusive mode'
  );
  call pg1c.execute_metadata_sql(metadata_table,
    'with data as ('||v_newline||
    '  select * from unnest('||pg_catalog.quote_literal(v_xml_enum_type.members)||'::text[]) with ordinality m(Ссылка,Порядок)'||v_newline||
    '),'||v_newline||
    'inserted as ('||v_newline||
    '  insert into '||metadata_table.schema||'.'||metadata_table.name_pg||v_newline|| 
    '    select Ссылка,(select coalesce(max(Порядок),0) Порядок from '||metadata_table.schema||'.'||metadata_table.name_pg||')+row_number() over () from data'||v_newline||
    '      where Ссылка not in (select Ссылка from '||metadata_table.schema||'.'||metadata_table.name_pg||')'||v_newline||
    '      order by data.Порядок'||v_newline||
    ')'||v_newline||
    'delete from '||metadata_table.schema||'.'||metadata_table.name_pg||' where Ссылка not in (select Ссылка from data)'
  );
  call pg1c.execute_metadata_sql(metadata_table,
    'update pg1c.table set row_count = (select count(1) from '||metadata_table.schema||'.'||metadata_table.name_pg||')'||v_newline||   
    '  where server_1c='||quote_literal(metadata_table.server_1c)||' and name_1c='||quote_literal(metadata_table.name_1c)    
  );  
end; $$;

create or replace procedure pg1c.create_functions$enum(metadata_table pg1c.metadata_table) language plpgsql as $body$
declare
  v_xml_enum_type pg1c.metadata_xml_enum_type;
  v_newline char := E'\n';
  v_sql_exception text :=
    '  raise exception using'||v_newline||
    '    errcode = ''S8108'','||v_newline||
    '    message = '||quote_literal(format('PG1C-8108 Обновление данных таблицы 1С %s невозможно, т.к. они являются метаданными',quote_literal(metadata_table.name_1c)))||','||v_newline||
    '    hint    = ''При необходимости используйте процедуры обновления метаданных, например pg1c.refresh_metadata'';';
begin
  if exists (select from pg_proc p where pronamespace=metadata_table.schema::regnamespace::oid and proname=(parse_ident(metadata_table.name_pg))[1]) then
    return;
  end if;
  call pg1c.refresh_metadata_only$enum(metadata_table);
  call pg1c.execute_metadata_sql(metadata_table,
    'create function '||metadata_table.schema||'.'||metadata_table.name_pg||'() returns setof '||metadata_table.schema||'.'||metadata_table.name_pg||' security definer language plpgsql as $$'||v_newline||
    'begin '||v_newline||
    v_sql_exception||v_newline||
    'end; $$'
  );
  call pg1c.execute_metadata_sql(metadata_table,
    'create function '||metadata_table.schema||'.'||metadata_table.name_pg||'(Ссылка text) returns '||metadata_table.schema||'.'||metadata_table.name_pg||' security definer language plpgsql as $$'||v_newline||
    'begin '||v_newline||
    v_sql_exception||v_newline||
    'end; $$'
  );   
  call pg1c.set_function_access(metadata_table,'');   
  call pg1c.set_function_access(metadata_table,'text'); 
end; $body$;


create or replace procedure pg1c.lock_server_1c(server_1c varchar) language plpgsql as $$
begin
  if not pg_try_advisory_xact_lock('pg1c'::regnamespace::oid::int,hashtext(server_1c)) then
    raise exception using
      errcode = 'S8109',
      message = format('PG1C-8109 Для сервера 1C %s полное обновление метаданных или данных выполняет другой процесс', quote_literal(server_1c)),
      hint    = 'Повторите операцию позже или игнорируйте';
  end if;
end; $$;

create or replace function pg1c.metadata_tables(server_1c varchar default 'DEFAULT') returns table(table_1c varchar) security definer language plpgsql as $$
begin
  call pg1c.load_metadata_xml(pg1c.server_1c(server_1c));
  return query
    select regexp_replace(et.table_1c, '(.*)_RecordType$', '\1')::varchar from pg1c_metadata_xml_entity_type et where root and et.server_1c=metadata_tables.server_1c
    union all
    select et.table_1c from pg1c_metadata_xml_enum_type et where et.server_1c=metadata_tables.server_1c;
end; $$;

create or replace procedure pg1c.create_table_all(server_1c varchar default 'DEFAULT', commit_tables int default 100) language plpgsql as $$
declare
  v_tables_1c varchar[];
begin
  call pg1c.lock_server_1c(server_1c);
  v_tables_1c := (
    select array_agg(table_1c order by table_1c)
      from pg1c.metadata_tables(server_1c)
      where table_1c not in (select name_1c from pg1c.table t where t.server_1c=create_table_all.server_1c)  
  );
  for i in 1..coalesce(array_length(v_tables_1c,1),0) loop
    perform pg1c.create_table(v_tables_1c[i],server_1c);
    if commit_tables is not null and i%commit_tables=0 then
      commit;
      call pg1c.lock_server_1c(server_1c);
    end if;
  end loop; 
  commit; 
end; $$;

create or replace procedure pg1c.drop_table_all(server_1c varchar default 'DEFAULT', commit_tables int default 100) language plpgsql as $$
declare
  v_tables_1c varchar[];
begin
  call pg1c.lock_server_1c(server_1c);
  v_tables_1c := (select array_agg(name_1c order by name_1c) from pg1c.table t where t.server_1c=drop_table_all.server_1c);
  for i in 1..coalesce(array_length(v_tables_1c,1),0) loop
    call pg1c.drop_table(v_tables_1c[i],server_1c);
    if commit_tables is not null and i%commit_tables=0 then
      commit;
      call pg1c.lock_server_1c(server_1c);
    end if;
  end loop; 
  commit; 
end; $$;

create or replace procedure pg1c.refresh_all(server_1c varchar default null, commit_tables int default 1) language plpgsql as $$
declare
  v_servers_1c varchar[] := case when server_1c is not null then array[server_1c] else (select coalesce(array_agg(id order by id),array[]::varchar[]) from pg1c.server_1c) end;
  v_server_1c varchar;
  v_tables_1c varchar[];
begin
  foreach v_server_1c in array v_servers_1c loop
    call pg1c.lock_server_1c(v_server_1c);
    v_tables_1c := (
      select array_agg(name_1c order by name_1c)
        from pg1c.table t
        where t.server_1c=v_server_1c
          and metadata_type!='Enumeration'
    ); 
    for i in 1..coalesce(array_length(v_tables_1c,1),0) loop
      call pg1c.refresh_metadata(v_tables_1c[i], v_server_1c,true);
      if commit_tables is not null and i%commit_tables=0 then
        commit;
        call pg1c.lock_server_1c(v_server_1c);
      end if;
    end loop; 
    commit;
  end loop; 
end; $$;

create or replace procedure pg1c.refresh_data_all(server_1c varchar default null, fast boolean default false, commit_tables int default 1) language plpgsql as $$
declare
  v_servers_1c varchar[] := case when server_1c is not null then array[server_1c] else (select coalesce(array_agg(id order by id),array[]::varchar[]) from pg1c.server_1c) end;
  v_server_1c varchar;
  v_tables_1c varchar[];
begin
  foreach v_server_1c in array v_servers_1c loop
    call pg1c.lock_server_1c(v_server_1c);
    v_tables_1c := (
      select array_agg(name_1c order by name_1c)
        from pg1c.table t
        where t.server_1c=v_server_1c
          and metadata_type!='Enumeration'
          and (not fast or row_count<fetch_size)
    ); 
    for i in 1..coalesce(array_length(v_tables_1c,1),0) loop
      call pg1c.refresh_data(v_tables_1c[i], v_server_1c);      
      if commit_tables is not null and i%commit_tables=0 then
        commit;
        call pg1c.lock_server_1c(v_server_1c);
      end if;
    end loop; 
    commit;
  end loop; 
end; $$;

revoke usage on schema pg1c from public;
revoke execute on all functions  in schema pg1c from public;
revoke execute on all procedures in schema pg1c from public;


