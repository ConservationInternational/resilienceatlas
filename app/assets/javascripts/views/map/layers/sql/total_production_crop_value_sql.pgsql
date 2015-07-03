with foo as (SELECT iso3, sum(y2012) as total FROM value_of_production_e_all_data_grp where element = 'Gross Production Value (current million US$)' group by iso3)

SELECT l.the_geom_webmercator,l.the_geom, l.iso3, foo.total,l.region FROM foo Left join grpcountries_250k_polygon l on foo.iso3=l.iso3 where region='Horn'