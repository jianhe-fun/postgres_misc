begin;
create table customer(
    customer_ref  text primary key ,
    customer_name text not null,
    street text,
    city text,
    state text,
    zip text,
    order_ct integer default 0,
    constraint order_ct_max1000 check(order_ct <=4)
);

create table orders(
  order_num text primary key,
  order_date date,
  customer_ref text,
  constraint customer_ref_fkey foreign key (customer_ref)
                   references customer(customer_ref) match simple
                   on update cascade on delete cascade
);
--add leading 0.
insert into customer(customer_ref, customer_name)
SELECT to_char(i,'fm0000'), 'alias' || i::text
FROM generate_series(1, 12) AS t(i);
commit ;
--insert some orders.
insert into orders (order_num,order_date,customer_ref)
values ('20220213001','2022-02-13','0003'),
values ('20220213002','2022-02-13','0003');
----------------------------------------------------------
--the following part is implementation for UPDATE, DELETE, INSERT operation for table orders.

create or replace function f_trigger_order_up()
returns trigger as
    $$
    begin
    if OLD.customer_ref <> NEW.customer_ref THEN
        update customer
        set order_ct = order_ct -1
            where customer_ref = OLD.customer_ref;

        update customer
        set order_ct  = order_ct + 1
            where customer_ref = NEW.customer_ref;
    end if;

    return null;
    end
    $$ language plpgsql;

--udpate trigger
create or replace trigger trigger_up_orders
    after update on orders for each row
    execute procedure f_trigger_order_up();


create or replace function f_trigger_order_in()
returns trigger as
    $$
    begin
        update customer set  order_ct =  order_ct + 1
        where customer_ref = NEW.customer_ref;
        return null;
    end;
    $$ language plpgsql;

--insert trigger.
create trigger trigger_in_orders
    AFTER INSERT ON orders FOR EACH ROW
    execute procedure f_trigger_order_in();


create or replace function trg_order_delaft()
returns trigger as
    $$
    BEGIN
        update customer set order_ct = order_ct -1
        where customer_ref = OLD.customer_ref;
        return  null;
    end;
$$
language plpgsql;

--delete  trigegr
create trigger trigger_del_orders
    AFTER DELETE ON orders FOR EACH ROW
execute procedure trg_order_delaft();

