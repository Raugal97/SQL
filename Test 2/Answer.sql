Example: (https://www.db-fiddle.com/f/wCuPT8cYhcPwq2XNxf4F6/0)

1)
select
	client_id
from
	(
	select
		client_id,
    		string_agg(product, '') as product_agg
	from clients
	group by client_id
		) as table_1
where 
	product_agg not like '%airpods%'
	and
	product_agg like '%iphone%'

2)             
select
  	right_1.client_id
from
	(
	select 
      		client_id
	from
      		(
        		select
          			client_id,
          			(case when product = 'airpods' then 1 else 0 end) as airpods_buy
        		from clients
        		group by client_id, product
      			) as table_1
  	group by client_id
  	having sum(airpods_buy) = 0
  				) as left_1
inner join
  	(
	select
		client_id
	from
		(
        		select
          			client_id,
          			(case when product = 'iphone' then 1 else 0 end) as proverka_2
        		from clients
        		group by client_id, product
      			) as table_2
  	group by client_id
	having sum(proverka_2) = 1
				) as right_1
on left_1.client_id = right_1.client_id