ActiveAdmin.register Indicator do
  config.sort_order = "position_asc"
  config.paginate = false

  sortable

  permit_params :name, :slug, :version, :position, :column_name, :operation, :category_id, model_ids: []

  filter :models, as: :select
  filter :category, as: :select
  filter :name, as: :select
  filter :slug, as: :select
  filter :version, as: :select
  filter :column_name, as: :select
  filter :operation, as: :select
  filter :created_at
  filter :updated_at

  index as: :sortable do
    label :label do |indicator|
      "#{indicator.name} - #{indicator.category&.name}"
    end
    actions
  end

  form do |f|
    f.semantic_errors

    f.inputs "Indicator fields" do
      f.input :category
      f.input :position
      f.input :name
      f.input :slug
      f.input :version
      f.input :column_name
      f.input :operation
      f.input :models
    end

    f.actions
  end
end
