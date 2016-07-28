ActiveAdmin.register Source do
  permit_params :source_type, :reference, :reference_short, :url, :contact_name,
                :contact_email, :license, :last_updated, :version, :spatial_resolution_units, :license_url

  form do |f|
    f.semantic_errors

    f.inputs 'Source Details' do
      f.input :source_type
      f.input :reference
      f.input :reference_short
      f.input :url
      f.input :contact_name
      f.input :contact_email
      f.input :license
      f.input :last_updated, as: :date_picker
      f.input :version
      f.input :spatial_resolution_units, as: :select, collection: %w{Kilometers Degrees}
      f.input :license_url, as: :string
      f.actions
    end
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
end
