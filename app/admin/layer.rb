ActiveAdmin.register Layer do
  permit_params :layer_group_id, :name, :slug, :layer_type, :zindex, :active, :order, :color, :info, :interactivity
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
    f.actions
    end
  end
end
