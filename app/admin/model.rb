ActiveAdmin.register Model do
  permit_params :name, :description, :source, site_scope_ids: [], indicator_ids: []

  index do
    selectable_column

    column :id
    column :name
    column :description
    column :source
    column :site_scopes do |model|
      links = []
      model.site_scopes.map do |ss|
        links << link_to(ss.name, admin_site_scope_path(ss.id))
        links << ' '
      end
      links.reduce(:+)
    end
    column :indicators do |model|
      links = []
      model.indicators.map do |indicator|
        links << link_to(indicator.name, admin_indicator_path(indicator.id))
        links << ' '
      end
      links.reduce(:+)
    end

    actions
  end

  form do |f|
    f.semantic_errors

    f.inputs 'Model' do
      f.input :name
      f.input :site_scopes
    end

    f.inputs 'Metadata' do
      f.input :description
      f.input :source
      f.input :indicators
    end
    f.actions
  end
end
