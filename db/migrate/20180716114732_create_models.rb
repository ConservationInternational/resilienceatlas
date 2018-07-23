class CreateModels < ActiveRecord::Migration
  def change
    create_table :models do |t|
      t.string :name, null: false
      t.text :description
      t.text :source
    end

    create_table :indicators do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :version
      t.boolean :analysis_suitable, default: false
      t.text :analysis_query

      t.index :slug
    end

    create_join_table :models, :site_scopes
    create_join_table :indicators, :models
  end
end
