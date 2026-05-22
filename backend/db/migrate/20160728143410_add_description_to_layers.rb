class AddDescriptionToLayers < ActiveRecord::Migration[6.0]
  def change
    add_column :layers, :description, :text
  end
end
