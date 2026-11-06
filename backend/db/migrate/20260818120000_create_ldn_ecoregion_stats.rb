class CreateLdnEcoregionStats < ActiveRecord::Migration[7.2]
  def up
    execute "CREATE SCHEMA IF NOT EXISTS ra_nonspatial"
    execute <<~SQL
      CREATE TABLE IF NOT EXISTS ra_nonspatial.ldn_ecoregion_stats (
        methodology          text NOT NULL,
        eco_id               integer NOT NULL,
        gains_km2            double precision,
        losses_km2           double precision,
        total_area_km2       double precision,
        deg_to_deg_sqkm      double precision,
        deg_to_stable_sqkm   double precision,
        deg_to_imp_sqkm      double precision,
        delta_ldn_km2        double precision,
        ldn_pct              double precision,
        PRIMARY KEY (methodology, eco_id)
      );
    SQL
  end

  def down
    execute "DROP TABLE IF EXISTS ra_nonspatial.ldn_ecoregion_stats"
  end
end
