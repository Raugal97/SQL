--	1.	На каждый день количество просмотров отдельно по 
--	монетизациям SVOD и AVOD на платформах 10 и 11 за последние 30 дней.
select 
	coalesce (case when paid_type = 'AVOD' then amount_view
		end, 0) as amount_view_avod
	, 'AVOD' as paid_type_avod
	, coalesce (case when paid_type = 'SVOD' then amount_view
		end, 0) as amount_view_svod
	, 'SVOD' as paid_type_svod
	, date_view
from (
	select 
		count(*) as amount_view
		, c.paid_type
		, cw.show_date::date as date_view
	from public.content_watch cw
	inner join content c 
		on cw.content_id = c.content_id 
	where
		c.paid_type in ('SVOD', 'AVOD')
		and 
		cw.platform in ('10', '11')
	group by c.paid_type, cw.show_date::date
	) t
where date_view > (current_date - interval '30 day')::date
order by date_view desc
--limit 30 -- еще можно сделать оконку row_number и по ней отфилтровать 30 строк