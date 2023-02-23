ActiveAdmin.register Model do
  permit_params :name, :description, :source, :table_name,
                :query_analysis,
                site_scope_ids: [], indicator_ids: []

  filter :site_scopes, as: :select
  filter :indicators, as: :select, collection: proc { Indicator.joins(:category).map{|m| [m.name, m.id]} }
  filter :name, as: :select
  filter :source, as: :select
  filter :table_name, as: :select

  index do
    selectable_column

    column :id
    column :name
    column :description
    column :source
    column :table_name
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
      f.input :table_name
      f.input :query_analysis
    end

    f.inputs 'Metadata' do
      f.input :description
      f.input :source
      f.input :indicators
    end
    f.actions
  end
end
