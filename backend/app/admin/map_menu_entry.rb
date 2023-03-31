ActiveAdmin.register MapMenuEntry do
  includes :translations
  sortable tree: true
  permit_params :link, :ancestry, :position,
    translations_attributes: [:id, :locale, :label, :_destroy]

  index as: :sortable do
    label :label
    actions
  end

  show do
    attributes_table do
      row :id
      row :label
      row :link
      row :ancestry
      row :position
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.semantic_errors

    f.inputs "Translated fields" do
      f.translated_inputs switch_locale: false do |ff|
        ff.input :label
      end
    end

    f.inputs "Map Menu Entry fields" do
      f.input :link
      f.input :position
    end

    f.actions
  end
end
