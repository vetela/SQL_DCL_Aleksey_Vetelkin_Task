-- Making the SQL command rerunnable and reusable
do
$$
begin
   if exists (select 1 from pg_roles where rolname = 'rentaluser') then
      drop owned by rentaluser cascade;
      drop user rentaluser;
   end if;
   if exists (select 1 from pg_roles where rolname = 'rental') then
      drop owned by rental cascade;
      drop user rental;
   end if;
end
$$ 
language plpgsql;

-- 1
-- Create a new user with the username "rentaluser" and the password "rentalpassword". 
-- Give the user the ability to connect to the database but no other permissions.
create user rentaluser with password 'rentalpassword';
grant connect on database dvdrental to rentaluser;


-- 2
-- Grant "rentaluser" SELECT permission for the "customer" table.
grant select on customer to rentaluser;

-- Сheck to make sure this permission works correctly—write a SQL query to select all customers.
set role rentaluser;
select * from customer;
reset role;


-- 3
-- Create a new user group called "rental" and add "rentaluser" to the group. 
create group rental;
grant rental to rentaluser;


-- 4
-- Grant the "rental" group INSERT and UPDATE permissions for the "rental" table. 
grant insert, update on rental to rental;
grant usage on sequence rental_rental_id_seq to rental;

-- Insert a new row and update one existing row in the "rental" table under that role. 
set role rentaluser;
insert into rental (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
values (current_timestamp, 1, 1, current_timestamp, 1, current_timestamp);
-- granting select for 1 update just to use 'Where'
reset role;
grant select on rental to rental;
set role rentaluser;
update rental set return_date = current_timestamp where rental_id = 1;
reset role;
revoke select on rental from rental;


-- 5
-- Revoke the "rental" group's INSERT permission for the "rental" table. 
revoke insert on rental from rental;
-- Try to insert new rows into the "rental" table make sure this action is denied.

-- Handling the exception to let query keep going after it
do
$$
begin
    set role rentaluser;
    begin
        insert into rental (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
        values (current_timestamp, 1, 1, current_timestamp, 1, current_timestamp);
    exception when insufficient_privilege then
        raise notice 'Insufficient privileges to insert into the rental table.';
    end;
    reset role;
exception when others then
    raise notice 'An error occurred: %', SQLERRM;
end 
$$;

-- 6
-- Create a personalized role for any customer already existing in the dvd_rental database

-- Making the SQL command rerunnable and reusable
do
$$
begin
   if exists (select 1 from pg_roles where rolname = 'client_mary_smith') then
      drop owned by client_mary_smith cascade;
      drop user client_mary_smith;
   end if;
end
$$ 
language plpgsql;

-- query to choose the customer
select c.customer_id, c.first_name, c.last_name
from customer c
where exists (select 1 from payment p where p.customer_id = c.customer_id)
and exists (select 1 from rental r where r.customer_id = c.customer_id)
limit 1;
-- creating a role
create role client_mary_smith;
-- configuring
create or replace view client_mary_smith_rentals as
select * from rental where customer_id = 1;
create or replace view client_mary_smith_payments as
select * from payment where customer_id = 1;
grant select on client_mary_smith_rentals, client_mary_smith_payments to client_mary_smith;
-- a query to make sure this user sees only their own data
set role client_mary_smith;
select * from client_mary_smith_rentals;
select * from client_mary_smith_payments;
-- checking that permission denied for not "mary_smith" info
-- select * from payment;
-- select * from rental;
reset role;
