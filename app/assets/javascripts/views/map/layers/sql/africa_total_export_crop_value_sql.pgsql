with foo as (select iso3, sum(value) as total from trade_crops_livestock_e_all_data_grp
where element= 'Export Value' and year=2011
group by iso3)

SELECT l.the_geom_webmercator,l.the_geom, l.iso3,l, region, foo.total FROM foo Left join grpcountries_250k_polygon l on foo.iso3=l.iso3 where region ='Horn'