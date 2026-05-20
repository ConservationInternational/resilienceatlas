ActiveAdmin.register_page "Dataset Inventory" do
  menu label: "Dataset Inventory", parent: "Data", priority: 5

  # ── Upload nonspatial CSV to ra_nonspatial schema ────────────────────────
  page_action :upload_nonspatial, method: :post do
    require "csv"
    require "tempfile"

    table_name = params[:table_name].to_s
      .gsub(/[^a-zA-Z0-9_]/, "_").downcase.slice(0, 63).presence
    csv_file   = params[:csv_file]

    if table_name.blank? || csv_file.blank?
      redirect_to admin_dataset_inventory_path(section: "nonspatial"),
        alert: "Table name and CSV file are required."
      return
    end

    if csv_file.size > 50.megabytes
      redirect_to admin_dataset_inventory_path(section: "nonspatial"),
        alert: "File too large (max 50 MB). For larger files use the rake cartodb:import_tables task."
      return
    end

    nonspatial_schema = DatasetInventoryService::NONSPATIAL_SCHEMA
    ar_conn = ActiveRecord::Base.connection

    begin
      col_types = CartodbRakeHelpers.infer_column_types_from_file(csv_file.path, limit: 2_000)
      raise "No columns detected in the CSV file." if col_types.blank?

      q_schema = ar_conn.quote_table_name(nonspatial_schema)
      q_table  = ar_conn.quote_table_name(table_name)
      ar_conn.execute("CREATE SCHEMA IF NOT EXISTS #{q_schema}")
      ar_conn.execute("DROP TABLE IF EXISTS #{q_schema}.#{q_table}")
      col_defs = col_types.map { |c, t| "#{ar_conn.quote_column_name(c)} #{t}" }.join(", ")
      ar_conn.execute("CREATE TABLE #{q_schema}.#{q_table} (#{col_defs})")

      raw_conn = ar_conn.raw_connection
      File.open(csv_file.path, "rb") do |f|
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

      redirect_to admin_dataset_inventory_path(section: "nonspatial"),
        notice: "Loaded #{number_with_delimiter(row_count)} rows into #{nonspatial_schema}.#{table_name}."
    rescue => e
      redirect_to admin_dataset_inventory_path(section: "nonspatial"),
        alert: "Upload failed: #{e.message.truncate(300)}"
    end
  end

  content title: "Dataset Inventory" do
    div class: "inventory-about" do
      para "An inventory of all datasets loaded into the Resilience Atlas database and object storage. " \
           "Use the tabs to browse PostGIS vector tables (ra_vector schema), raster tables (ra_raster schema), " \
           "non-spatial attribute tables (ra_nonspatial schema), and Cloud-Optimised GeoTIFF files on S3. " \
           "Columns are sortable; use the search boxes to filter by table name or associated layer."
    end

    section = params[:section].presence&.in?(%w[vector raster nonspatial s3]) ? params[:section] : "vector"
    page = [params[:page].to_i, 1].max
    per_page = 25
    sort = params[:sort].presence || ((section == "s3") ? "key" : "name")
    dir = (params[:dir] == "desc") ? "desc" : "asc"
    name_q = params[:q].presence
    layer_q = params[:lq].presence

    base = {section: section, sort: sort, dir: dir, q: name_q, lq: layer_q}

    svc = DatasetInventoryService.new

    # ── Tab bar ──────────────────────────────────────────────────────────────
    div class: "inventory-tabs" do
      [
        ["vector", "Vector Tables"],
        ["raster", "Raster Tables"],
        ["nonspatial", "Nonspatial Tables"],
        ["s3", "S3 COGs"]
      ].each do |tab, label|
        text_node link_to(label, admin_dataset_inventory_path(section: tab),
          class: "inventory-tab#{(section == tab) ? " active" : ""}")
      end
    end

    # ── Search / filter form ─────────────────────────────────────────────────
    if section != "nonspatial"
      div class: "inventory-filters" do
        form action: admin_dataset_inventory_path, method: :get do
          input type: :hidden, name: :section, value: section
          input type: :hidden, name: :sort, value: sort
          input type: :hidden, name: :dir, value: dir
          span do
            label(for: :q) { "Name:" }
            input type: :text, name: :q, id: :q, value: name_q,
              placeholder: (section == "s3") ? "Filter by S3 key…" : "Filter by table name…",
              style: "width:200px; margin:0 6px"
          end
          span do
            label(for: :lq) { "Used by layer:" }
            input type: :text, name: :lq, id: :lq, value: layer_q,
              placeholder: "layer name or slug…", style: "width:180px; margin:0 6px"
          end
          input type: :submit, value: "Filter", class: "button"
          if name_q.present? || layer_q.present?
            span { " " }
            link_to "Clear", admin_dataset_inventory_path(section: section), class: "button"
          end
        end
      end
    end

    # ── Content by section ───────────────────────────────────────────────────
    case section
    when "vector", "raster"
      schema = (section == "vector") ? DatasetInventoryService::VECTOR_SCHEMA : DatasetInventoryService::RASTER_SCHEMA
      result = (section == "vector") ?
        svc.vector_tables(page: page, per_page: per_page, sort: sort, dir: dir, q: name_q, lq: layer_q) :
        svc.raster_tables(page: page, per_page: per_page, sort: sort, dir: dir, q: name_q, lq: layer_q)

      panel "#{(section == "vector") ? "Vector" : "Raster"} Tables (#{schema} schema) — #{result[:total]} tables" do
        if result[:rows].empty?
          para((name_q.present? || layer_q.present?) ? "No tables match the current filters." : "No tables found in #{schema} schema.")
        else
          table_for result[:rows], class: "inventory-table" do
            column(sort_link("Table Name", "name", sort, dir, base.merge(page: 1))) do |r|
              link_to r[:name], admin_dataset_table_viewer_path(schema: schema, table: r[:name])
            end
            column(sort_link("Rows", "row_count", sort, dir, base.merge(page: 1))) { |r|
              number_with_delimiter(r[:row_count])
            }
            column(sort_link("Size", "size_bytes", sort, dir, base.merge(page: 1))) { |r|
              format_bytes(r[:size_bytes])
            }
            column("Used By Layers") do |r|
              if r[:layers].any?
                safe_join(r[:layers].map { |l|
                  link_to "#{l[:slug]} (#{l[:name]})", admin_layer_path(l[:id])
                }, ", ".html_safe)
              else
                content_tag(:em, "unused")
              end
            end
          end
          text_node inventory_pagination(result, base)
        end
      end

    when "nonspatial"
      schema = DatasetInventoryService::NONSPATIAL_SCHEMA
      result = svc.nonspatial_tables(page: page, per_page: per_page, sort: sort, dir: dir, q: name_q, lq: layer_q)

      # ── Detect filter form for nonspatial (no layer filter — nonspatial tables are rarely direct layer sources) ──
      div class: "inventory-filters" do
        form action: admin_dataset_inventory_path, method: :get do
          input type: :hidden, name: :section, value: "nonspatial"
          input type: :hidden, name: :sort, value: sort
          input type: :hidden, name: :dir, value: dir
          span do
            label(for: :q) { "Name:" }
            input type: :text, name: :q, id: :q, value: name_q,
              placeholder: "Filter by table name…",
              style: "width:200px; margin:0 6px"
          end
          input type: :submit, value: "Filter", class: "button"
          if name_q.present?
            span { " " }
            link_to "Clear", admin_dataset_inventory_path(section: "nonspatial"), class: "button"
          end
        end
      end

      panel "Nonspatial Tables (#{schema} schema) — #{result[:total]} tables" do
        if result[:rows].empty?
          para(name_q.present? ? "No tables match the current filter." : "No tables found in #{schema} schema.")
        else
          table_for result[:rows], class: "inventory-table" do
            column(sort_link("Table Name", "name", sort, dir, base.merge(page: 1))) do |r|
              link_to r[:name], admin_dataset_table_viewer_path(schema: schema, table: r[:name])
            end
            column(sort_link("Rows", "row_count", sort, dir, base.merge(page: 1))) { |r|
              number_with_delimiter(r[:row_count])
            }
            column(sort_link("Size", "size_bytes", sort, dir, base.merge(page: 1))) { |r|
              format_bytes(r[:size_bytes])
            end
          end
          text_node inventory_pagination(result, base)
        end
      end

      # ── Upload CSV → ra_nonspatial ────────────────────────────────────────
      panel "Upload CSV to #{schema}" do
        para "Upload a plain .csv file to create or replace a table in the #{schema} schema. " \
             "Column types are inferred automatically. Maximum file size: 50 MB."
        render partial: "admin/dataset_inventory/upload_nonspatial_form"
      end

    when "s3"
      result = svc.s3_cogs(page: page, per_page: per_page, sort: sort, dir: dir, q: name_q, lq: layer_q)
      prefix_label = ENV["COG_PREFIX"].presence || "cogs/"

      panel "S3 COG Objects (#{prefix_label} prefix) — #{result[:total]} objects" do
        if svc.s3_error
          div class: "flash flash_error" do
            "S3 not available: #{svc.s3_error}"
          end
        elsif result[:rows].empty?
          para((name_q.present? || layer_q.present?) ? "No objects match the current filters." : "No COG objects found.")
        else
          table_for result[:rows], class: "inventory-table" do
            column(sort_link("S3 Key", "key", sort, dir, base.merge(page: 1))) { |r| r[:key] }
            column(sort_link("Size", "size_bytes", sort, dir, base.merge(page: 1))) { |r|
              format_bytes(r[:size_bytes])
            }
            column(sort_link("# Layers", "layers", sort, dir, base.merge(page: 1))) { |r|
              r[:layers].size
            }
            column("Used By Layers") do |r|
              if r[:layers].any?
                safe_join(r[:layers].map { |l|
                  link_to "#{l[:slug]} (#{l[:name]})", admin_layer_path(l[:id])
                }, ", ".html_safe)
              else
                content_tag(:em, "unused")
              end
            end
          end
          text_node inventory_pagination(result, base)
        end
      end
    end
  end

  controller do
    helper DatasetInventoryHelper
  end
end
