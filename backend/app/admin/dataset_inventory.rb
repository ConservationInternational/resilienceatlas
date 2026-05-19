ActiveAdmin.register_page "Dataset Inventory" do
  menu label: "Dataset Inventory", parent: "Data", priority: 5

  content title: "Dataset Inventory" do
    div class: "inventory-about" do
      para "An inventory of all datasets loaded into the Resilience Atlas database and object storage. Use the tabs to browse PostGIS vector tables (ra_vector schema), raster tables (ra_raster schema), and Cloud-Optimised GeoTIFF files on S3. Columns are sortable; use the search boxes to filter by table name or associated layer."
    end

    section = params[:section].presence&.in?(%w[vector raster s3]) ? params[:section] : "vector"
    page    = [params[:page].to_i, 1].max
    per_page = 25
    sort    = params[:sort].presence || (section == "s3" ? "key" : "name")
    dir     = params[:dir] == "desc" ? "desc" : "asc"
    name_q  = params[:q].presence
    layer_q = params[:lq].presence

    base = {section: section, sort: sort, dir: dir, q: name_q, lq: layer_q}

    svc = DatasetInventoryService.new

    # ── Tab bar ──────────────────────────────────────────────────────────────
    div class: "inventory-tabs" do
      [["vector", "Vector Tables"], ["raster", "Raster Tables"], ["s3", "S3 COGs"]].each do |tab, label|
        text_node link_to(label, admin_dataset_inventory_path(section: tab),
          class: "inventory-tab#{section == tab ? " active" : ""}")
      end
    end

    # ── Search / filter form ─────────────────────────────────────────────────
    div class: "inventory-filters" do
      form action: admin_dataset_inventory_path, method: :get do
        input type: :hidden, name: :section, value: section
        input type: :hidden, name: :sort,    value: sort
        input type: :hidden, name: :dir,     value: dir
        span do
          label(for: :q) { "Name:" }
          input type: :text, name: :q, id: :q, value: name_q,
            placeholder: section == "s3" ? "Filter by S3 key…" : "Filter by table name…",
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

    # ── Content by section ───────────────────────────────────────────────────
    case section
    when "vector", "raster"
      schema = section == "vector" ? DatasetInventoryService::VECTOR_SCHEMA : DatasetInventoryService::RASTER_SCHEMA
      result = section == "vector" ?
        svc.vector_tables(page: page, per_page: per_page, sort: sort, dir: dir, q: name_q, lq: layer_q) :
        svc.raster_tables(page: page, per_page: per_page, sort: sort, dir: dir, q: name_q, lq: layer_q)

      panel "#{section == "vector" ? "Vector" : "Raster"} Tables (#{schema} schema) — #{result[:total]} tables" do
        if result[:rows].empty?
          para(name_q.present? || layer_q.present? ? "No tables match the current filters." : "No tables found in #{schema} schema.")
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

    when "s3"
      result = svc.s3_cogs(page: page, per_page: per_page, sort: sort, dir: dir, q: name_q, lq: layer_q)
      prefix_label = ENV["COG_PREFIX"].presence || "cogs/"

      panel "S3 COG Objects (#{prefix_label} prefix) — #{result[:total]} objects" do
        if svc.s3_error
          div class: "flash flash_error" do
            "S3 not available: #{svc.s3_error}"
          end
        elsif result[:rows].empty?
          para(name_q.present? || layer_q.present? ? "No objects match the current filters." : "No COG objects found.")
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
