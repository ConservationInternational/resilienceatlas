SELECT
  cartodb_id AS id,
  ST_ASGeoJSON(the_geom) AS geom
FROM utm_trans_airport_130509