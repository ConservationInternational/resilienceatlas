ActiveAdmin.register Source do
  includes :translations
  permit_params :source_type, :url, :contact_name, :contact_email, :last_updated, :version, :spatial_resolution_units, :license_url,
    translations_attributes: [:id, :locale, :reference, :reference_short, :license, :_destroy]

  filter :layers, as: :select, collection: proc { Layer.with_translations.map { |m| [m.name, m.id] } }
  filter :translations_reference_cont, as: :string, label: "Reference"
  filter :translations_reference_short_cont, as: :string, label: "Reference Short"
  filter :translations_license_eq, as: :select, label: "License", collection: proc { Source.with_translations.pluck(:license) }
  filter :source_type
  filter :contact_name
  filter :contact_email
  filter :last_updated
  filter :version
  filter :spatial_resolution_units

  form do |f|
    f.semantic_errors

    f.inputs "Translated fields" do
      f.translated_inputs switch_locale: false do |ff|
        ff.input :reference
        ff.input :reference_short
        ff.input :license
      end
    end

    f.inputs "Source Details" do
      f.input :source_type
      f.input :url
      f.input :contact_name
      f.input :contact_email
      f.input :license_url, as: :string
      f.input :last_updated, as: :date_picker
      f.input :version
      f.input :spatial_resolution_units, as: :select, collection: %w[Kilometers Degrees]
    end

    f.actions
  end

  index do
    selectable_column
    column :id
    column :source_type
    column :reference
    column :last_updated
    column :version
    actions
  end

  show do
    attributes_table do
      row :source_type
      row :reference
      row :reference_short
      row :url
      row :contact_name
      row :contact_email
      row :license
      row :license_url
      row :version
      row :spatial_resolution_units
      row :created_at
      row :updated_at
      row :last_updated
    end
  end
end
