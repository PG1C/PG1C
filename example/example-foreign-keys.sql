-- Создание ключа в момент создания таблицы
create table myorders(
  id serial primary key, 
  partner_id uuid references Справочник.Контрагенты deferrable initially deferred
);

-- Создание ключа для существующей таблицы 2 способами:
-- сокращенное, имя будет сформировано автоматически 
alter table myorders add foreign key (partner_id)
  references Справочник.Контрагенты deferrable initially deferred;
-- полное с указанием имени и поля первичного ключа
alter table myorders add constraint myorders_partner_fk foreign key (partner_id)
  references Справочник.Контрагенты(Ссылка) deferrable initially deferred;