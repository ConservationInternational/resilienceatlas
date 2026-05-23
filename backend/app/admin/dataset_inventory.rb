ActiveAdmin.register_page "Dataset Inventory" do
  menu label: "Dataset Inventory", parent: "Data", priority: 5

  # ── Refresh cached inventory data ────────────────────────────────────────────
  page_action :refresh_cache, method: :post do
    DatasetInventoryService.invalidate_all_caches!
    redirect_to admin_dataset_inventory_path(section: params[:section].presence || "vector"),
      notice: "Cache cleared — the next page load will re-scan all schemas and S3."
  end

  content title: "Dataset Inventory" do
    section = params[:section].presence&.in?(%w[vector raster nonspatial s3]) ? params[:section] : "vector"

    div class: "inventory-about" do
      refresh_form = [
        %(<form action="/admin/dataset_inventory/refresh_cache" method="post" style="float:right;margin:0">),
        %(<input type="hidden" name="authenticity_token" value="#{ERB::Util.html_escape(form_authenticity_token)}">),
        %(<input type="hidden" name="section" value="#{ERB::Util.html_escape(section)}">),
        %(<input type="submit" value="↺ Refresh Cache" class="button" ),
        %(title="Clear cached inventory data and force a full re-scan on next page load">),
        %(</form>)
      ].join.html_safe
      text_node refresh_form
      para "An inventory of all datasets loaded into the Resilience Atlas database and object storage. " \
           "Use the tabs to browse PostGIS vector tables (ra_vector schema), raster tables (ra_raster schema), " \
           "non-spatial attribute tables (ra_nonspatial schema), and Cloud-Optimised GeoTIFF files on S3. " \
           "Columns are sortable; use the search boxes to filter by table name or associated layer."
    end

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
              r[:row_count].nil? ? content_tag(:em, "—", title: "Row count unavailable for views") : number_with_delimiter(r[:row_count])
            }
            column(sort_link("Size", "size_bytes", sort, dir, base.merge(page: 1))) { |r|
              format_bytes(r[:size_bytes])
            }
            column("Used By Layers") do |r|
              if r[:layers].any?
                safe_join(r[:layers].map { |l|
                  if section == "vector"
                    (link_to("#{l[:slug]} (#{l[:name]})", admin_layer_path(l[:id])) +
                      " ".html_safe +
                      link_to("(replace)", import_vector_admin_layer_path(l[:id]),
                        style: "font-size:0.8em; color:#888;",
                        title: "Import a new vector file for layer #{l[:slug]}")
                    ).html_safe
                  else
                    link_to "#{l[:slug]} (#{l[:name]})", admin_layer_path(l[:id])
                  end
                }, ", ".html_safe)
              else
                content_tag(:em, "unused")
              end
            end
          end
          text_node inventory_pagination(result, base)
        end
      end

      if section == "raster"
        panel "About Raster Tables" do
          para "Raster tables in the #{DatasetInventoryService::RASTER_SCHEMA} schema are populated via the CartoDB migration rake task " \
               "(rake cartodb:import_tables). There is no admin upload interface for raster tables."
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
              r[:row_count].nil? ? content_tag(:em, "—", title: "Row count unavailable for views") : number_with_delimiter(r[:row_count])
            }
            column(sort_link("Size", "size_bytes", sort, dir, base.merge(page: 1))) { |r|
              format_bytes(r[:size_bytes])
            }
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
                  (link_to("#{l[:slug]} (#{l[:name]})", admin_layer_path(l[:id])) +
                    " ".html_safe +
                    link_to("(replace)", upload_cog_admin_layer_path(l[:id]),
                      style: "font-size:0.8em; color:#888;",
                      title: "Upload a new COG for layer #{l[:slug]}")
                  ).html_safe
                }, ", ".html_safe)
              else
                content_tag(:em, "unused")
              end
            end
          end
          text_node inventory_pagination(result, base)
        end
      end

      panel "Recent COG Uploads" do
        recent = DataImport.where(import_type: "cog")
          .order(created_at: :desc).limit(8)
        if recent.any?
          table_for recent do
            column(:id)
            column("Target") do |di|
              data_import_target_link(di)
            end
            column(:file_name)
            column("Size") { |di| di.formatted_file_size }
            column(:status) { |di| status_tag di.status }
            column("At") { |di| di.created_at.strftime("%Y-%m-%d %H:%M") }
            column("") { |di| link_to "Details", admin_data_import_path(di) }
          end
          text_node link_to "View all imports →", admin_data_imports_path(q: {import_type_eq: "cog"})
        else
          para "No COG uploads recorded yet."
        end
      end
    end
  end

  controller do
    helper DatasetInventoryHelper
  end
end
