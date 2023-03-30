class CreateAgrupations < ActiveRecord::Migration[6.0]
  def change
    create_table :agrupations do |t|
      t.references :layer, index: true, foreign_key: true
      t.references :layer_group, index: true, foreign_key: true
    end
  end
end
