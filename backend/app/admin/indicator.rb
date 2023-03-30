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

  # FIXME: Check which way we should display the indicators
  # As the gem active_admin-sortable_tree doesn't display
  # a table and we have to check for incompatibilities

  # index do
  #   column :position
  #   column :category
  #   column :name
  #   column :slug
  #   column :column_name
  #   column :operation
  #   column :models do |indicator|
  #     links = []
  #     indicator.models.map do |model|
  #       links << link_to(model.name, admin_model_path(model.id))
  #     end
  #     links.reduce(:+)
  #   end
  #
  #   actions
  # end

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
