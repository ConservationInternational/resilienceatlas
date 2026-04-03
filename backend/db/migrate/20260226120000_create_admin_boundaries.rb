class CreateAdminBoundaries < ActiveRecord::Migration[7.2]
  def up
    # Ensure PostGIS is available (idempotent — no-op if already enabled)
    execute "CREATE EXTENSION IF NOT EXISTS postgis"

    create_table :admin_boundaries do |t|
      t.string :name
      t.string :iso_code       # ISO 3166-1 alpha-3 for ADM0, sub-codes for ADM1/ADM2
      t.integer :admin_level, null: false, default: 0 # 0 = country, 1 = province/state, 2 = district
      t.string :parent_iso_code # references the parent boundary's iso_code

      t.timestamps
    end

    # Modern PostGIS syntax (no legacy AddGeometryColumn wrapper needed)
    execute <<-SQL
      ALTER TABLE admin_boundaries
        ADD COLUMN geom geometry(MultiPolygon, 4326) NOT NULL;
    SQL

    add_index :admin_boundaries, :admin_level
    add_index :admin_boundaries, :iso_code
    add_index :admin_boundaries, :geom, using: :gist
  end

  def down
    drop_table :admin_boundaries
  end
end
