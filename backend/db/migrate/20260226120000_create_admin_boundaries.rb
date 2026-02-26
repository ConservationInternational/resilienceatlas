class CreateAdminBoundaries < ActiveRecord::Migration[7.2]
  def up
    create_table :admin_boundaries do |t|
      t.string :name, null: false
      t.string :iso_code       # ISO 3166-1 alpha-3 for ADM0, sub-codes for ADM1/ADM2
      t.integer :admin_level, null: false, default: 0 # 0 = country, 1 = province/state, 2 = district
      t.string :parent_iso_code # references the parent boundary's iso_code

      t.timestamps
    end

    # Use raw SQL for geometry column — works regardless of whether
    # activerecord-postgis-adapter is fully loaded at migration time
    execute <<-SQL
      SELECT AddGeometryColumn('public', 'admin_boundaries', 'geom', 4326, 'MULTIPOLYGON', 2);
      ALTER TABLE admin_boundaries ALTER COLUMN geom SET NOT NULL;
    SQL

    add_index :admin_boundaries, :admin_level
    add_index :admin_boundaries, :iso_code
    add_index :admin_boundaries, :geom, using: :gist
  end

  def down
    drop_table :admin_boundaries
  end
end
