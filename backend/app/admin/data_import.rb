ActiveAdmin.register DataImport do
  menu label: "Data Imports", parent: "Data", priority: 4

  sidebar "About", only: :index do
    para "Tracks bulk data import jobs triggered from the admin interface. Review import history and check the status of in-progress or failed imports."
  end


  actions :index, :show

  filter :status, as: :select, collection: DataImport.statuses.keys
  filter :import_type, as: :select, collection: DataImport.import_types.keys
  filter :admin_user, as: :select, collection: proc { AdminUser.all.map { |u| [u.email, u.id] } }
  filter :created_at

  index do
    column :id
    column "Uploaded at", :created_at
    column "Uploaded by" do |di|
      di.admin_user&.email
    end
    column :file_name
    column "Size" do |di|
      di.formatted_file_size
    end
    column :import_type
    column :importable do |di|
      if di.importable
        link_to "#{di.importable_type} ##{di.importable_id}",
          polymorphic_path([:admin, di.importable])
      end
    end
    column :status do |di|
      status_tag di.status, class: status_class(di.status)
    end
    column "Duration" do |di|
      next "—" unless di.duration
      "#{di.duration.round(1)}s"
    end
    actions
  end

  show do
    attributes_table do
      row :id
      row "Uploaded at", &:created_at
      row "Uploaded by" do |di|
        di.admin_user&.email
      end
      row :file_name
      row :s3_key
      row "File size", &:formatted_file_size
      row :import_type
      row :importable do |di|
        if di.importable
          link_to "#{di.importable_type} ##{di.importable_id}",
            polymorphic_path([:admin, di.importable])
        end
      end
      row :status do |di|
        status_tag di.status, class: status_class(di.status)
      end
      row :rows_imported
      row :started_at
      row :completed_at
      row "Duration" do |di|
        next "—" unless di.duration
        "#{di.duration.round(1)}s"
      end
      row :error_message do |di|
        pre(class: "code-block") { di.error_message } if di.error_message.present?
      end
    end
  end

  controller do
    helper_method :status_class

    def status_class(status)
      case status.to_s
      when "complete" then "yes"
      when "failed" then "no"
      when "processing" then "orange"
      else ""
      end
    end
  end
end
