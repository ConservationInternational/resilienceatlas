select
  iso3 as iso,
  region,
  s_name as country
from
  grpcountries_250k_polygon
group by
region, iso3, s_name
