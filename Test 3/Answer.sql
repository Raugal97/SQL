1)

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
--limit 30 -- or we can do row_number and filter 30 by that

2)

with top5_serial as ( --count top5 serials
select 
	count(distinct user_id) as count_people
	, compilation_id as serial_number
	, null::int as content_id
	, date_trunc('month', cw.show_date) as month_watch
	, rank() over(partition by date_trunc('month', cw.show_date) 
		order by count(distinct user_id) desc) 
		as rnk
	, 'serial' as type_content
from public.content_watch cw
inner join content c 
	on cw.content_id = c.content_id
where compilation_id != '' --must be "is not null" :)
group by compilation_id, date_trunc('month', cw.show_date)
),

top5_ed_content as( --count top5 other content
select 
	count(distinct user_id) as count_people
	, null::varchar as serial_number
	, c.content_id	
	, date_trunc('month', cw.show_date) as month_watch
	, rank() over(partition by date_trunc('month', cw.show_date) 
		order by count(distinct user_id) desc) 
		as rnk
	, 'ed_content' as type_content
from public.content_watch cw
inner join content c 
	on cw.content_id = c.content_id
where compilation_id = ''
group by date_trunc('month', cw.show_date), c.content_id
)

select *
from top5_serial
where rnk <= 5

union all

select *
from top5_ed_content
where rnk <= 5

--select * --alternative final
--from top5_serial srl
--inner join top5_ed_content cont
--	on srl.month_watch = cont.month_watch 
--	and srl.rnk = cont.rnk
--where rnk <= 5

3)

select
	user_id
from (
	select 
		user_id
		, string_agg(lower(utm_medium), '-' order by show_date asc) as list_source
		, date_trunc('day', show_date)::date as day_watch 
	from public.content_watch cw
	inner join content c 
		on cw.content_id = c.content_id
	group by user_id, date_trunc('day', show_date)::date
		) t
where 
	day_watch = (current_date - interval '1 day')::date
	and
	list_source like '%organic-referral%'
	
4)

-- Based on watch_id = 4458319751, we conclude that the user can start with the 1st episode of the series and 
-- continue to watch further (i.e. the next series), which indicates a duration of about ~ 200 minutes (i.e. clearly not one series)
-- => we assume that the user can have several sessions per day, i.e. a long session goes on if the series (content) go one after the other
-- , and a new session starts when other content is manually enabled.

-- Metrics: 
4-1) The average duration of one session when the series is turned on
	select 
		compilation_id as serial_number
		, round(avg(show_duration/60)) as avg_timespend_per_session
		, rank() over(order by round(avg(show_duration/60))) as rnk_serial 
	from public.content_watch cw
	inner join content c 
		on cw.content_id = c.content_id
	where compilation_id != '' -- only serials
	group by compilation_id
	
-- If it is possible to add data, then I would make an adjustment for the average duration of the series in the series
4-2) 
-- The average number of episodes per session when the series is turned on
	round(avg(show_duration) / avg(length_episode), 2) as avg_series_view -- and rang later on
	
4-3) 
-- Average rating of the series
	select 
		compilation_id as serial_number
		, avg(avg_rating) as average_rating
	from public.content_watch cw
	inner join content c 
		on cw.content_id = c.content_id
	where compilation_id != '' -- only serials
	group by compilation_id
	
4-4) 
-- The share of views from the total volume per month. We can estimate how much time a particular series is watched per month
-- and how much % does the series take of the total number of TV series views this month
	with sum_by_month as (
		select 
			date_trunc('month', show_date) as month_dt
			, sum(show_duration) as sum_by_month
		from public.content_watch cw
		inner join content c 
			on cw.content_id = c.content_id
		where compilation_id != '' -- only serials
		group by date_trunc('month', show_date)
	)
	
	select
		serial_number 
		, t.month_dt
		, round((sum_by_serial::decimal / sum_by_month::decimal) * 100, 2) as percent_from_total
	from (
		select 
			compilation_id as serial_number
			, date_trunc('month', show_date) as month_dt
			, sum(show_duration) as sum_by_serial
		from public.content_watch cw
		inner join content c 
			on cw.content_id = c.content_id
		where compilation_id != '' -- only serials
		group by compilation_id, date_trunc('month', show_date)
			) t
	left join sum_by_month sbm
		on sbm.month_dt = t.month_dt
			
4-5) 
-- Average percentage of inspection/viewing during the month
-- if user watcher more than 50% serial in a month we can assume that we got him
	with length_by_serial as (	
		select 
			compilation_id as serial_number
			, sum(length_episode) as sum_time_serial
		from public.content_watch cw
		inner join content c 
			on cw.content_id = c.content_id
		where compilation_id != '' -- only serials
		group by compilation_id
		)
	
	select 
		serial_number
		, month_dt 
		, avg(percent_view) as avg_percent_view
	from(
		select 
			user_id
			, compilation_id as serial_number
			, date_trunc('month', show_date) as month_dt
			, sum(show_duration) as sum_time
			, lbs.sum_time_serial as sum_time_serial
			, round((sum(show_duration)::decimal / lbs.sum_time_serial::decimal) * 100, 2) as percent_view
		from public.content_watch cw
		inner join content c 
			on cw.content_id = c.content_id
		inner join length_by_serial lbs 
			on lbs.serial_number = c.serial_number
		where compilation_id != '' -- only serials
		group by compilation_id, user_id, date_trunc('month', show_date)
		) t
	group by serial_number, month_dt
	
5)
--	Decided to segment users by platform and first session
	select
		count(user_id) as uniq_users --count users
		, round((count(user_id) / first_value(count(user_id)) over(partition by platform, first_month)) * 100, 2) as percent_from_start --we calculate how many % of users are left from the first month (for beauty, you can || '%')
		, platform
		, month_session
		, first_month 
		, months_between
	from(
		select 
			user_id 
			, platform
			, month_session
			, first_value(month_session) over(partition by user_id, platform order by month_session asc) as first_month --we fix the first month for the user-platform combination
			, round((month_session:: date - first_value(month_session) over(partition by user_id, platform)::date)/(365/12)) as months_between --count the number of months between the month of the first session and the months of the following sessions
		from(
			select 
				user_id
				, platform 
				, date_trunc('month', show_date) as month_session 
			from public.content_watch cw
			inner join content c 
				on cw.content_id = c.content_id
			group by user_id, platform, date_trunc('month', show_date) --group the sessions for the user in one line
				) t
					) tt
	group by platform, month_session, first_month, months_between
	order by platform, first_month asc
