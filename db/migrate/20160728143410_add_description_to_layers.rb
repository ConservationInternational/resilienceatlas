class AddDescriptionToLayers < ActiveRecord::Migration
  def change
    add_column :layers, :description, :text
  end
end
