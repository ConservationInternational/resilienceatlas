ActiveAdmin.register DataImport do
  menu label: "Data Uploads", parent: "Data", priority: 1
  actions :index, :show

  action_item :upload, only: :index, priority: 0 do
    link_to "Upload New Data", upload_admin_data_imports_path, class: "button"
  end

  collection_action :upload, method: :get do
    @target_layer = Layer.find(params[:layer_id]) if params[:layer_id].present?
    authorize! :update, @target_layer if @target_layer
    @resume = DataImport.find(params[:resume]) if params[:resume].present?
    if @resume && (@resume.admin_user_id != current_admin_user.id || !@resume.managed_upload?)
      raise CanCan::AccessDenied
    end
    Ability.new(current_admin_user).authorize_upload!(@resume, read_only: true) if @resume
    render :upload
  end

  filter :status, as: :select, collection: DataImport.statuses.keys
  filter :import_type, as: :select, collection: DataImport.import_types.keys
  filter :admin_user, as: :select, collection: proc { AdminUser.all.map { |user| [user.email, user.id] } }
  filter :created_at

  index title: "Data Uploads" do
    column :id
    column :created_at
    column("Uploaded by") { |di| di.admin_user&.email }
    column :file_name
    column("Size", &:formatted_file_size)
    column :import_type
    column("Target") { |di| data_import_target_link(di) }
    column :status
    column :stage
    actions
  end

  show do
    if resource.managed_upload? && resource.admin_user_id == current_admin_user.id
      para link_to("Open upload workspace", upload_admin_data_imports_path(resume: resource.id), class: "button")
    end
    attributes_table do
      row :id
      row :created_at
      row("Uploaded by") { |di| di.admin_user&.email }
      row :file_name
      row :s3_key
      row("File size", &:formatted_file_size)
      row :import_type
      row("Target") { |di| data_import_target_link(di) }
      row :status
      row :stage
      row :attempts
      row :rows_imported
      row :started_at
      row :completed_at
      row :job_id
      row(:error_message) { |di| pre(di.error_message) if di.error_message.present? }
      row(:metadata) { |di| pre(JSON.pretty_generate(di.metadata)) }
    end
  end

  # Retain the existing nonspatial form endpoint, independently of spatial uploads.
  collection_action :upload_file, method: :post do
    raise CanCan::AccessDenied unless current_admin_user.superadmin?
    file = params[:file]
    unless params[:upload_type] == "nonspatial" && file.present?
      redirect_to upload_admin_data_imports_path, alert: "Use the upload workspace for vector and raster files."
      next
    end
    table_name = params[:table_name].to_s
    unless table_name.match?(/\A[a-zA-Z0-9_]{1,63}\z/) && File.extname(file.original_filename).downcase == ".csv" && file.size <= 50.megabytes
      redirect_to upload_admin_data_imports_path, alert: "Choose a CSV up to 50 MB and a valid table name."
      next
    end
    begin
      conn = ActiveRecord::Base.connection
      types = CsvColumnTypeInferrer.infer(file.path, limit: 2_000)
      raise ArgumentError, "No columns detected in CSV" if types.blank?
      schema = conn.quote_table_name(DatasetInventoryService::NONSPATIAL_SCHEMA)
      table = conn.quote_table_name(table_name.downcase)
      conn.transaction do
        conn.execute("CREATE SCHEMA IF NOT EXISTS #{schema}")
        conn.execute("DROP TABLE IF EXISTS #{schema}.#{table}")
        columns = types.map { |name, type| "#{conn.quote_column_name(name)} #{type}" }.join(", ")
        conn.execute("CREATE TABLE #{schema}.#{table} (#{columns})")
        File.open(file.path, "rb") do |input|
          conn.raw_connection.copy_data("COPY #{schema}.#{table} FROM STDIN WITH (FORMAT csv, HEADER true, ENCODING 'UTF8', NULL '')") do
            while (chunk = input.read(65_536))
              conn.raw_connection.put_copy_data(chunk)
            end
          end
        end
        conn.execute("ANALYZE #{schema}.#{table}")
      end
      DatasetInventoryService.invalidate_all_caches!
      redirect_to admin_dataset_inventory_path(section: "nonspatial"), notice: "CSV loaded into #{table_name.downcase}."
    rescue => e
      Rails.logger.error "[CSV upload] #{e.class}: #{e.message}"
      redirect_to upload_admin_data_imports_path, alert: "CSV upload failed: #{e.message.truncate(300)}"
    end
  end

  controller do
    helper DatasetInventoryHelper
  end
end
