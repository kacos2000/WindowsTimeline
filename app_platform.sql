-- List all entries in the AppID json array

select
Activity.etag,
json_extract(Activity.AppId, '$[0].platform')  as 'p0' ,
json_extract(Activity.AppId, '$[0].application') as '0' ,
json_extract(Activity.AppId, '$[1].platform')  as 'p1' ,
json_extract(Activity.AppId, '$[1].application') as '1' ,
json_extract(Activity.AppId, '$[2].platform')  as 'p2' ,
json_extract(Activity.AppId, '$[2].application') as '2'  ,
json_extract(Activity.AppId, '$[3].platform')  as 'p3' ,
json_extract(Activity.AppId, '$[3].application') as '3' ,
json_extract(Activity.AppId, '$[4].platform')  as 'p4' ,
json_extract(Activity.AppId, '$[4].application') as '4',
json_extract(Activity.AppId, '$[5].platform')  as 'p5' ,
json_extract(Activity.AppId, '$[5].application') as '5' ,
json_extract(Activity.AppId, '$[6].platform')  as 'p6' ,
json_extract(Activity.AppId, '$[6].application') as '6' ,
json_extract(Activity.AppId, '$[7].platform')  as 'p7' ,
json_extract(Activity.AppId, '$[7].application') as '7' ,
json_extract(Activity.AppId, '$[8].platform')  as 'p8' ,
json_extract(Activity.AppId, '$[8].application') as '8'

from Activity
order by p5 desc