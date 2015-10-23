ActiveAdmin.register LayerGroup do
  permit_params :name, :slug, :category, :active, :order, :info, :layer_group_type, :super_group_id, :icon_class
  index do
    selectable_column
    column :id
    column :name
    column :type
    column :order
    column :updated_at
    actions
  end
end
