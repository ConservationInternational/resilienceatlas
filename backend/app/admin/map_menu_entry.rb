ActiveAdmin.register MapMenuEntry do
  includes :translations
  config.sort_order = "position_asc"
  permit_params :link, :ancestry, :position,
    translations_attributes: [:id, :locale, :label, :_destroy]

  index do
    selectable_column
    column :position
    column :label do |entry|
      # Indent based on ancestry depth to show hierarchy
      indent = "&nbsp;&nbsp;&nbsp;&nbsp;" * entry.depth
      (indent + entry.label).html_safe
    end
    column :link
    column :ancestry
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
