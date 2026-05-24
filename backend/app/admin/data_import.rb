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
    # Inject upload form HTML before the table
    text_node %{
      <div id="upload-section" class="panel" style="background: #f9f9f9; border: 2px solid #2c3e50; margin-bottom: 30px; padding: 20px;">
        <h3 style="color: #2c3e50; margin-top: 0;">Upload Data</h3>
        <p style="margin-bottom: 20px;">Select a file and specify its type to upload it to the appropriate location. After upload, configure layers manually to use the uploaded data.</p>

        <form action="#{upload_file_admin_data_imports_path}" method="post" enctype="multipart/form-data" id="unified-upload-form">
          <input type="hidden" name="authenticity_token" value="#{form_authenticity_token}">

          <div style="margin-bottom: 20px; padding: 15px; background: white; border-radius: 4px;">
            <fieldset style="border: none; padding: 0; margin: 0;">
              <legend style="font-weight: bold; margin-bottom: 12px;">1. Select File</legend>
              <input type="file" name="file" required style="width: 100%; max-width: 500px;">
            </fieldset>
          </div>

          <div style="margin-bottom: 20px; padding: 15px; background: white; border-radius: 4px;">
            <fieldset style="border: none; padding: 0; margin: 0;">
              <legend style="font-weight: bold; margin-bottom: 12px;">2. Specify Upload Type</legend>

              <div style="margin-bottom: 15px;">
                <label style="display: block; margin-bottom: 8px;">
                  <input type="radio" name="upload_type" value="vector" id="type-vector" required>
                  <strong>Vector Dataset</strong> (GeoPackage, GeoJSON, Shapefile)
                </label>
                <div id="vector-options" style="display: none; margin-left: 24px; margin-top: 8px; padding: 12px; background: #f5f5f5; border-left: 3px solid #3498db;">
                  <label for="vector_table_name" style="display: block; margin-bottom: 4px; font-weight: bold;">Table name suffix:</label>
                  <input type="text" name="table_name" id="vector_table_name" maxlength="54" pattern="[a-zA-Z0-9_]+" placeholder="e.g. mangrove_extent_2026" style="width: 280px;">
                  <span style="color: #666; font-size: 0.9em; display: block; margin-top: 4px;">
                    Letters, digits, underscores only. Will create <code>ra_vector.imported_<em>name</em></code>
                  </span>
                </div>
              </div>

              <div style="margin-bottom: 15px;">
                <label style="display: block; margin-bottom: 8px;">
                  <input type="radio" name="upload_type" value="cog" id="type-cog" required>
                  <strong>Cloud-Optimized GeoTIFF (COG)</strong>
                </label>
                <div id="cog-options" style="display: none; margin-left: 24px; margin-top: 8px; padding: 12px; background: #f5f5f5; border-left: 3px solid #e67e22;">
                  <p style="margin: 0; color: #666; font-size: 0.9em;">
                    Uploads to <code>s3://resilienceatlas/cogs/</code>. Configure layer manually after upload.
                  </p>
                </div>
              </div>

              <div>
                <label style="display: block; margin-bottom: 8px;">
                  <input type="radio" name="upload_type" value="nonspatial" id="type-nonspatial" required>
                  <strong>Nonspatial CSV Table</strong>
                </label>
                <div id="nonspatial-options" style="display: none; margin-left: 24px; margin-top: 8px; padding: 12px; background: #f5f5f5; border-left: 3px solid #27ae60;">
                  <label for="nonspatial_table_name" style="display: block; margin-bottom: 4px; font-weight: bold;">Table name:</label>
                  <input type="text" name="table_name" id="nonspatial_table_name" maxlength="63" pattern="[a-zA-Z0-9_]+" placeholder="e.g. dhs_indicators_gh" style="width: 280px;">
                  <span style="color: #666; font-size: 0.9em; display: block; margin-top: 4px;">
                    Letters, digits, underscores only. Creates <code>ra_nonspatial.<em>name</em></code>. Max 50 MB.
                  </span>
                  <p style="color: #c0392b; margin-top: 8px; margin-bottom: 0; font-size: 0.9em;">
                    <strong>Warning:</strong> This will drop and replace any existing table with the same name.
                  </p>
                </div>
              </div>
            </fieldset>
          </div>

          <div style="text-align: center; padding: 15px;">
            <input type="submit" value="Upload File" class="button" style="font-size: 16px; padding: 10px 30px;">
          </div>
        </form>

        <script>
        (function() {
          const form = document.getElementById('unified-upload-form');
          const vectorRadio = document.getElementById('type-vector');
          const cogRadio = document.getElementById('type-cog');
          const nonspatialRadio = document.getElementById('type-nonspatial');

          const vectorOptions = document.getElementById('vector-options');
          const cogOptions = document.getElementById('cog-options');
          const nonspatialOptions = document.getElementById('nonspatial-options');

          const vectorTableName = document.getElementById('vector_table_name');
          const nonspatialTableName = document.getElementById('nonspatial_table_name');

          function updateOptions() {
            vectorOptions.style.display = vectorRadio.checked ? 'block' : 'none';
            cogOptions.style.display = cogRadio.checked ? 'block' : 'none';
            nonspatialOptions.style.display = nonspatialRadio.checked ? 'block' : 'none';

            if (vectorRadio.checked) {
              vectorTableName.required = true;
              nonspatialTableName.required = false;
            } else if (nonspatialRadio.checked) {
              vectorTableName.required = false;
              nonspatialTableName.required = true;
            } else {
              vectorTableName.required = false;
              nonspatialTableName.required = false;
            }
          }

          vectorRadio.addEventListener('change', updateOptions);
          cogRadio.addEventListener('change', updateOptions);
          nonspatialRadio.addEventListener('change', updateOptions);

          form.addEventListener('submit', function(e) {
            if (vectorRadio.checked && !vectorTableName.value.trim()) {
              e.preventDefault();
              alert('Please enter a table name for the vector upload.');
              vectorTableName.focus();
              return false;
            }
            if (nonspatialRadio.checked && !nonspatialTableName.value.trim()) {
              e.preventDefault();
              alert('Please enter a table name for the nonspatial CSV upload.');
              nonspatialTableName.focus();
              return false;
            }
          });
        })();
        </script>
      </div>
    }.html_safe

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
      s3_uri = "s3://#{ENV.fetch("S3_BUCKET", "resilienceatlas")}/#{s3_key}"

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
