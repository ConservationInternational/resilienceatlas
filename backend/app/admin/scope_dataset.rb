ActiveAdmin.register ScopeDataset do
  permit_params :site_scope_id, :slug, :name, :description, :data_type,
    :group_key, :variant_label, :dimension, :dimension_config,
    :schema_config, :data, :chart_config, :display_order

  filter :site_scope, as: :select, collection: proc { SiteScope.with_translations.sort_by(&:name).map { |m| [m.name, m.id] } }
  filter :slug
  filter :name
  filter :data_type, as: :select, collection: %w[tabular]
  filter :group_key
  filter :dimension

  index do
    selectable_column
    column :id
    column :slug
    column :name
    column :site_scope do |d|
      link_to d.site_scope.name, admin_site_scope_path(d.site_scope)
    end
    column :data_type
    column :group_key
    column :dimension
    column :variant_label
    column "Rows" do |d|
      d.row_count
    end
    column "Geometries" do |d|
      d.geometry_count
    end
    column :display_order
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :slug
      row :name
      row :description
      row :site_scope do |d|
        link_to d.site_scope.name, admin_site_scope_path(d.site_scope)
      end
      row :data_type
      row :group_key
      row :dimension
      row :variant_label
      row :display_order
      row "Row count" do |d|
        d.row_count
      end
      row "Geometry count" do |d|
        d.geometry_count
      end
      row :created_at
      row :updated_at
    end

    panel "Dimension Config" do
      render "admin/shared/json_display", json: resource.dimension_config
    end

    panel "Schema Config" do
      render "admin/shared/json_display", json: resource.schema_config
    end

    panel "Chart Config" do
      render "admin/shared/json_display", json: resource.chart_config
    end

    panel "Data Preview (first 20 rows)" do
      rows = resource.data.is_a?(Array) ? resource.data.first(20) : []
      if rows.any?
        columns = resource.schema_config.is_a?(Array) ? resource.schema_config.map { |c| c["name"] } : rows.first.keys
        table_for rows do
          columns.each do |col_name|
            column(col_name) { |row| row[col_name] }
          end
        end
        if resource.row_count > 20
          para "... and #{resource.row_count - 20} more rows"
        end
      else
        para "No data"
      end
    end
  end

  form do |f|
    f.inputs "Dataset" do
      f.input :site_scope, as: :select, collection: SiteScope.with_translations.sort_by(&:name).map { |m| [m.name, m.id] }
      f.input :slug
      f.input :name
      f.input :description
      f.input :data_type, as: :select, collection: %w[tabular], include_blank: false
      f.input :group_key, hint: "Optional key to group variant datasets together (e.g. 'ecoregion-summary'). Datasets sharing a group_key appear as switchable variants in the UI."
      f.input :dimension, hint: "Dimension this dataset belongs to (e.g. 'ecoregion', 'country'). Used to group datasets into view modes with radio-button switching."
      f.input :variant_label, hint: "Human-readable label for this variant (e.g. 'JRC', 'FAO-WOCAT'). Shown in the variant selector dropdown."
      f.input :display_order
    end

    f.inputs "Dimension Config (JSON)" do
      f.input :dimension_config, as: :text, input_html: {
        class: "json-editor-textarea", rows: 6,
        value: f.object.dimension_config.present? ? JSON.pretty_generate(f.object.dimension_config) : ""
      },
        hint: 'JSON object with dimension metadata: {"unit_label": "Ecoregion", "unit_id_column": "eco_id", "name_column": "ecoregion"}'
    end

    f.inputs "Schema Config (JSON)" do
      f.input :schema_config, as: :text, input_html: {
        class: "json-editor-textarea", rows: 12,
        value: f.object.schema_config.present? ? JSON.pretty_generate(f.object.schema_config) : ""
      },
        hint: 'JSON array of column definitions: [{"name": "eco_id", "type": "integer", "label": "Ecoregion ID"}]'
    end

    f.inputs "Chart Config (JSON)" do
      f.input :chart_config, as: :text, input_html: {
        class: "json-editor-textarea", rows: 12,
        value: f.object.chart_config.present? ? JSON.pretty_generate(f.object.chart_config) : ""
      },
        hint: "JSON array of chart specifications"
    end

    f.inputs "Data (JSON)" do
      f.input :data, as: :text, input_html: {
        class: "json-editor-textarea", rows: 20,
        value: f.object.data.present? ? JSON.pretty_generate(f.object.data) : ""
      },
        hint: "JSON array of row objects. Use 'Import CSV' action on the show page for bulk import."
    end

    f.actions
  end

  # Import CSV member action
  member_action :import_csv, method: [:get, :post] do
    if request.post?
      if params[:csv_file].blank?
        redirect_to resource_path, alert: "No file selected"
        return
      end

      begin
        csv_content = params[:csv_file].read
        rows = CSV.parse(csv_content, headers: true, converters: :numeric).map(&:to_h)
        resource.update!(data: rows)
        redirect_to resource_path, notice: "Imported #{rows.size} rows from CSV"
      rescue CSV::MalformedCSVError => e
        redirect_to resource_path, alert: "CSV parse error: #{e.message}"
      end
    else
      render :import_csv
    end
  end

  # Export CSV member action
  member_action :export_csv, method: :get do
    rows = resource.data
    return redirect_to resource_path, alert: "No data to export" unless rows.is_a?(Array) && rows.any?

    columns = resource.schema_config.is_a?(Array) ? resource.schema_config.map { |c| c["name"] } : rows.first.keys

    csv_data = CSV.generate do |csv|
      csv << columns
      rows.each { |row| csv << columns.map { |c| row[c] } }
    end

    send_data csv_data,
      type: "text/csv; charset=UTF-8",
      filename: "#{resource.slug}.csv"
  end

  action_item :import_csv, only: [:show, :edit] do
    link_to "Import CSV", import_csv_admin_scope_dataset_path(resource)
  end

  action_item :export_csv, only: [:show, :edit] do
    link_to "Export CSV", export_csv_admin_scope_dataset_path(resource)
  end
end
