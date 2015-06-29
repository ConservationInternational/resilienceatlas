with foo as (select iso3, sum(value) as total, year from trade_crops_livestock_e_all_data_grp
where element= 'Export Value'
group by iso3, year)

SELECT l.the_geom_webmercator, l.iso3, foo.total, foo.year FROM foo Left join grpcountries_250k_polygon l on foo.iso3=l.iso3
