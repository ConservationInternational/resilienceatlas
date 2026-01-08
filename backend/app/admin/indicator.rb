ActiveAdmin.register Indicator do
  includes :translations
  config.sort_order = "position_asc"
  config.paginate = false

  sortable

  permit_params :slug, :version, :position, :column_name, :operation, :category_id, model_ids: [],
    translations_attributes: [:id, :locale, :name, :_destroy]

  filter :models, as: :select, collection: proc { Model.with_translations.pluck(:name) }
  filter :category, as: :select, collection: proc { Category.with_translations.pluck(:name) }
  filter :translations_name_eq, as: :select, label: "Name", collection: proc { Indicator.with_translations.pluck(:name) }
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

  show do
    attributes_table do
      row :id
      row :name
      row :slug
      row :version
      row :position
      row :category
      row :column_name
      row :operation
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.semantic_errors

    f.inputs "Translated fields" do
      f.translated_inputs switch_locale: false do |ff|
        ff.input :name
      end
    end

    f.inputs "Indicator fields" do
      f.input :category
      f.input :position
      f.input :slug
      f.input :version
      f.input :column_name
      f.input :operation
      f.input :models
    end

    f.actions
  end
end
