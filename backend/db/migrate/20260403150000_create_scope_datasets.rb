class CreateScopeDatasets < ActiveRecord::Migration[7.2]
  def change
    create_table :scope_datasets do |t|
      t.references :site_scope, null: false, foreign_key: true
      t.string :slug, null: false
      t.string :name, null: false
      t.text :description
      t.string :data_type, null: false, default: "tabular"
      t.jsonb :schema_config, null: false, default: []
      t.jsonb :data, null: false, default: []
      t.jsonb :chart_config, null: false, default: []
      t.integer :display_order, default: 0
      t.timestamps
    end

    add_index :scope_datasets, [:site_scope_id, :slug], unique: true
    add_index :scope_datasets, :slug
  end
end
