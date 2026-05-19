ActiveAdmin.register Category do
  menu label: "Categories", parent: "Data", priority: 1

  sidebar "About", only: :index do
    para "Categories group related indicators together for display in the map's layer panel. Each category contains one or more indicators and organises how data themes are presented."
  end

  includes :translations, indicators: :translations
  permit_params :slug, indicator_ids: [],
    translations_attributes: [:id, :locale, :name, :description, :_destroy]

  filter :translations_name_eq, as: :select, label: "Name", collection: proc { Category.with_translations.pluck(:name) }
  filter :slug, as: :select
  filter :translations_description_eq, as: :select, label: "Description", collection: proc { Category.with_translations.pluck(:description) }
  filter :indicators, as: :select, collection: proc { Indicator.with_translations.map { |m| [m.name, m.id] } }

  index do
    selectable_column

    column :id
    column :name
    column :slug
    column :description
    column :indicators do |category|
      links = []
      category.indicators.map do |indicator|
        links << link_to(indicator.name, admin_indicator_path(indicator.id))
      end
      links.reduce(:+)
    end

    actions
  end

  show do
    attributes_table do
      row :id
      row :name
      row :slug
      row :description
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
      end
    end

    f.inputs "Category fields" do
      f.input :slug
      f.input :indicators
    end

    f.actions
  end
end
