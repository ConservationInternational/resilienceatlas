ActiveAdmin.register Layer do
  permit_params :layer_group_id, :name, :slug, :layer_type, :zindex, :active, :order, :color, :info, :interactivity, :query, :layer_provider, :css, :published, :opacity, :locate_layer, :icon_class, :legend, :zoom_max, :zoom_min
  form do |f|
    f.inputs 'Layer Details' do
    f.semantic_errors
    f.input :layer_group
    f.input :name
    f.input :slug
    f.input :layer_type
    f.input :opacity
    f.input :zindex
    f.input :active
    f.input :order
    f.input :color, as: :string
    f.input :info
    f.input :interactivity
    f.input :query
    f.input :layer_provider
    f.input :css
    f.input :locate_layer
    f.input :icon_class
    f.input :legend
    f.input :zoom_max
    f.input :zoom_min
    f.actions
    end
  end
  index do
    selectable_column
    column :id
    column :name
    column :info
    column :provider
    column :css
    column :query
    column :info
    column :updated_at
    actions
  end
end
