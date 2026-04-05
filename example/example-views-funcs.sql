-- ! Создание представлений с непосредственным использовнием таблиц не рекомендуется,
-- т.к. при обновлении метаданных из-за особенностей PostgreSQL может возникнуть исключение
-- Рекомендуется создавать функции-оберки и использовать их в представлениях, см. ниже
create or replace view myview1 as 
  select * from Справочник.Товары where not ПометкаУдаления; 
alter table Справочник.Товары ... ; -- ! Возможно исключение при использовании myview1

-- Функция на языке SQL, выдача прав пользователю
create or replace function myquery1()
  returns setof Справочник.Товары language sql as
$$
  select * from Справочник.Товары where not ПометкаУдаления;
$$;
grant execute on function myquery1 to user_1; 

-- Функция на языке plpgsql, которая: обновляет таблицу, 
-- создает на ее основе временную таблицу, возвращает SQL-запрос  
-- Определение возвращаемых полей необходимо для возможности
-- использования в представлениях      
create or replace function myquery2()
  returns table(Ссылка uuid,ПометкаУдаления boolean) language plpgsql as
$$
begin
  perform Справочник.Товары();
  create temp table temp_myquery2 on commit drop as
    select * from Справочник.Товары limit 10;
  return query select Ссылка,ПометкаУдаления from temp_myquery2;
end 
$$;

-- Функция с параметром и динамическим SQL-запросом
create or replace function myquery3(lim int)
  returns table(Ссылка uuid,ПометкаУдаления boolean) language plpgsql as
$$
begin
  return query  
    execute $SQL$
       select Ссылка,ПометкаУдаления from Справочник.Товары limit $1
    $SQL$
    using lim;
end 
$$;

-- Создание обычного и материализованного представлений на основе функции
-- Обновление метаданных не приведет к исключению, т.к. нет прямой связи с таблицей
create or replace view myview2 as select * from myquery2(); 
create materialized view myview3 as select * from myquery3(20);
refresh materialized view myview3;
grant select on myview2,myview3 to user_1;