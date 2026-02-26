class CreateAdminBoundaries < ActiveRecord::Migration[7.2]
  def change
    create_table :admin_boundaries do |t|
      t.string :name, null: false
      t.string :iso_code       # ISO 3166-1 alpha-3 for ADM0, sub-codes for ADM1/ADM2
      t.integer :admin_level, null: false, default: 0 # 0 = country, 1 = province/state, 2 = district
      t.string :parent_iso_code # references the parent boundary's iso_code
      t.multi_polygon :geom, srid: 4326, null: false

      t.timestamps
    end

    add_index :admin_boundaries, :admin_level
    add_index :admin_boundaries, :iso_code
    add_index :admin_boundaries, :geom, using: :gist
    add_index :admin_boundaries, [:admin_level, :geom], using: :gist, name: "index_admin_boundaries_on_level_and_geom"
  end
end
