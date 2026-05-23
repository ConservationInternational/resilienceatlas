ActiveAdmin.register DataImport do
  menu label: "Data Uploads", parent: "Data", priority: 1

  actions :index, :show

  # ── Unified upload interface ────────────────────────────────────────────
  action_item :upload, only: :index, priority: 0 do
    link_to "Upload New Data", "#upload-section", class: "button", onclick: "document.getElementById('upload-section').scrollIntoView({behavior: 'smooth'}); return false;"
  end

  filter :status, as: :select, collection: DataImport.statuses.keys
  filter :import_type, as: :select, collection: DataImport.import_types.keys
  filter :admin_user, as: :select, collection: proc { AdminUser.all.map { |u| [u.email, u.id] } }
  filter :created_at

  index title: "Data Uploads" do
    render partial: "upload_interface"
    h3 "Upload History"
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

  # ── Upload actions ──────────────────────────────────────────────────────
  collection_action :upload_file, method: :post do
    upload_type = params[:upload_type]
    uploaded_file = params[:file]

    if uploaded_file.blank?
      redirect_to admin_data_imports_path, alert: "Please select a file to upload."
      return
    end

    case upload_type
    when "vector"
      handle_vector_upload(uploaded_file)
    when "cog"
      handle_cog_upload(uploaded_file)
    when "nonspatial"
      handle_nonspatial_upload(uploaded_file)
    else
      redirect_to admin_data_imports_path, alert: "Please select a valid upload type."
    end
  end

  controller do
    helper_method :status_class
    include DatasetInventoryHelper

    def status_class(status)
      case status.to_s
      when "complete" then "yes"
      when "failed" then "no"
      when "processing" then "orange"
      else ""
      end
    end

    private

    def handle_vector_upload(file)
      table_name = params[:table_name].to_s.gsub(/[^a-zA-Z0-9_]/, "_").downcase.slice(0, 54)

      if table_name.blank?
        redirect_to admin_data_imports_path, alert: "Table name is required for vector uploads."
        return
      end

      # Upload to S3 staging area
      s3_key = upload_to_s3(file, "staging/#{table_name}")

      di = DataImport.create!(
        importable: current_admin_user,
        admin_user: current_admin_user,
        file_name: file.original_filename,
        s3_key: s3_key,
        file_size_bytes: file.size,
        import_type: "vector",
        status: "pending"
      )

      VectorImportJob.perform_later(di.id)
      redirect_to admin_data_imports_path, notice: "Vector file uploaded. Import job queued for ra_vector.imported_#{table_name}."
    end

    def handle_cog_upload(file)
      s3_key = upload_to_s3(file, "cogs")
      s3_uri = "s3://#{ENV.fetch('S3_BUCKET', 'resilienceatlas')}/#{s3_key}"

      DataImport.create!(
        importable: current_admin_user,
        admin_user: current_admin_user,
        file_name: file.original_filename,
        s3_key: s3_key,
        file_size_bytes: file.size,
        import_type: "cog",
        status: "complete",
        started_at: Time.current,
        completed_at: Time.current
      )

      redirect_to admin_data_imports_path, notice: "COG uploaded to #{s3_uri}. Configure a layer to use this file."
    end

    def handle_nonspatial_upload(file)
      table_name = params[:table_name].to_s.gsub(/[^a-zA-Z0-9_]/, "_").downcase.slice(0, 63)

      if table_name.blank?
        redirect_to admin_data_imports_path, alert: "Table name is required for nonspatial CSV uploads."
        return
      end

      if file.size > 50.megabytes
        redirect_to admin_data_imports_path, alert: "File too large (max 50 MB)."
        return
      end

      nonspatial_schema = DatasetInventoryService::NONSPATIAL_SCHEMA
      ar_conn = ActiveRecord::Base.connection

      begin
        col_types = CsvColumnTypeInferrer.infer(file.path, limit: 2_000)
        raise "No columns detected in CSV." if col_types.blank?

        q_schema = ar_conn.quote_table_name(nonspatial_schema)
        q_table = ar_conn.quote_table_name(table_name)
        ar_conn.execute("CREATE SCHEMA IF NOT EXISTS #{q_schema}")
        ar_conn.execute("DROP TABLE IF EXISTS #{q_schema}.#{q_table}")
        col_defs = col_types.map { |c, t| "#{ar_conn.quote_column_name(c)} #{t}" }.join(", ")
        ar_conn.execute("CREATE TABLE #{q_schema}.#{q_table} (#{col_defs})")

        raw_conn = ar_conn.raw_connection
        File.open(file.path, "rb") do |f|
          raw_conn.copy_data(
            "COPY #{q_schema}.#{q_table} FROM STDIN WITH (FORMAT csv, HEADER true, ENCODING 'UTF8', NULL '')"
          ) do
            while (chunk = f.read(65_536))
              raw_conn.put_copy_data(chunk)
            end
          end
        end

        row_count = ar_conn.select_value("SELECT COUNT(*) FROM #{q_schema}.#{q_table}").to_i
        ar_conn.execute("ANALYZE #{q_schema}.#{q_table}")
        DatasetInventoryService.invalidate_all_caches!

        redirect_to admin_data_imports_path, notice: "Loaded #{helpers.number_with_delimiter(row_count)} rows into #{nonspatial_schema}.#{table_name}."
      rescue => e
        redirect_to admin_data_imports_path, alert: "Upload failed: #{e.message.truncate(300)}"
      end
    end

    def upload_to_s3(file, prefix)
      bucket = ENV.fetch("S3_BUCKET", "resilienceatlas")
      region = ENV.fetch("AWS_REGION", "us-east-1")
      s3_key = "#{prefix}/#{SecureRandom.uuid}_#{file.original_filename}"

      client = Aws::S3::Client.new(
        region: region,
        access_key_id: ENV["AWS_ACCESS_KEY_ID"],
        secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"]
      )

      client.put_object(
        bucket: bucket,
        key: s3_key,
        body: file.read,
        content_type: file.content_type
      )

      s3_key
    end
  end
end
