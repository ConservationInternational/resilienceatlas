ActiveAdmin.register Indicator do
  config.sort_order = 'position_asc'
  config.paginate   = false

  sortable

  permit_params :name, :slug, :version, :position, :category_id, model_ids: []

  index do
    sortable_handle_column

    id_column
    column :category
    column :name
    column :slug
    column :models do |indicator|
      links = []
      indicator.models.map do |model|
        links << link_to(model.name, admin_model_path(model.id))
      end
      links.reduce(:+)
    end

    actions
  end

  form do |f|
    f.semantic_errors

    f.inputs 'Indicator fields' do
      f.input :category
      f.input :position
      f.input :name
      f.input :slug
      f.input :version
      f.input :models
    end

    f.actions
  end
end
