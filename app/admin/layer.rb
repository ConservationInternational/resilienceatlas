ActiveAdmin.register Layer do
  permit_params :layer_group_id, :name, :slug, :layer_type, :zindex, :active, :order, :color, :info, :interactivity, :query, :layer_provider, :css, :published, :opacity, :locate_layer, :icon_class, :legend, :zoom_max, :zoom_min, :dashboard_order, :dataset_shortname, :dataset_source_url
  form do |f|
    f.semantic_errors
    f.inputs 'Layer Details' do
    f.input :name
    f.input :slug
    f.input :layer_type
    f.input :opacity
    f.input :zindex
    f.input :active
    f.input :order
    f.input :dashboard_order
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
    f.input :download
    f.input :dataset_shortname
    f.input :dataset_source_url, as: :string
    f.actions
    end
  end
  index do
    selectable_column
    column :id
    column :name
    column :provider
    column :download
    column :css
    column :query
    column :info
    column :updated_at
    actions
  end
end
