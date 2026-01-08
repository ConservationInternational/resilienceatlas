class AddColumnIconClassToLayerGroups < ActiveRecord::Migration[6.0]
  def change
    add_column :layer_groups, :icon_class, :string
    add_column :layers, :published, :boolean, default: true
  end
end
