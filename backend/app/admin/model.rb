ActiveAdmin.register Model do
  includes :translations, site_scopes: :translations, indicators: :translations
  permit_params :table_name, :query_analysis, site_scope_ids: [], indicator_ids: [],
    translations_attributes: [:id, :locale, :name, :description, :source, :_destroy]

  filter :site_scopes, as: :select, collection: proc { SiteScope.with_translations.map { |m| [m.name, m.id] } }
  filter :indicators, as: :select, collection: proc { Indicator.with_translations.map { |m| [m.name, m.id] } }
  filter :translations_name_eq, as: :select, label: "Name", collection: proc { Model.with_translations.pluck(:name) }
  filter :translations_source_eq, as: :select, label: "Source", collection: proc { Model.with_translations.pluck(:source) }
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
        links << " "
      end
      links.reduce(:+)
    end
    column :indicators do |model|
      links = []
      model.indicators.map do |indicator|
        links << link_to(indicator.name, admin_indicator_path(indicator.id))
        links << " "
      end
      links.reduce(:+)
    end

    actions
  end

  show do
    attributes_table do
      row :id
      row :name
      row :description
      row :source
      row :query_analysis
      row :table_name
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.semantic_errors

    f.inputs "Translated fields" do
      f.translated_inputs switch_locale: false do |ff|
        ff.input :name
        ff.input :description
        ff.input :source
      end
    end

    f.inputs "Model" do
      f.input :site_scopes
      f.input :table_name
      f.input :query_analysis
    end

    f.inputs "Metadata" do
      f.input :indicators
    end
    f.actions
  end
end
