ActiveAdmin.register Source do
  permit_params :source_type, :reference, :reference_short, :url, :contact_name,
                :contact_email, :license, :last_updated, :version

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
      f.input :last_updated
      f.input :version
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
