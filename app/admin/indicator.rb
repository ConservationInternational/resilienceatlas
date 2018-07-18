ActiveAdmin.register Indicator do
  permit_params :name, :slug, :version, :analysis_suitable,
                :analysis_query, model_ids: []

  index do
    selectable_column

    column :id
    column :name
    column :slug
    column :analysis_suitable
    column :analysis_query
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
      f.input :name
      f.input :slug
      f.input :version
      f.input :analysis_suitable
      f.input :analysis_query
      f.input :models
    end

    f.actions
  end
end
