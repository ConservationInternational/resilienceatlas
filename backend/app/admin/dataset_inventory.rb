ActiveAdmin.register_page "Dataset Inventory" do
  menu label: "Dataset Inventory", parent: "Data"

  content title: "Dataset Inventory" do
    svc = DatasetInventoryService.new
    vector_tables = svc.vector_tables
    raster_tables = svc.raster_tables
    cogs = svc.s3_cogs

    div class: "inventory-refresh" do
      para do
        link_to "↻ Refresh", admin_dataset_inventory_path, class: "button"
        span " (rescans live DB and S3 on every load)", style: "color: #888; font-size: 0.85em;"
      end
    end

    # ── ra_vector tables ───────────────────────────────────────────────────────
    panel "Vector Tables (ra_vector schema) — #{vector_tables.size} tables" do
      if vector_tables.empty?
        para "No tables found in ra_vector schema."
      else
        table_for vector_tables do
          column("Table name") { |r| r[:name] }
          column("Rows") { |r| number_with_delimiter(r[:row_count]) }
          column("Size") { |r| format_bytes(r[:size_bytes]) }
          column("Used by layers") do |r|
            if r[:layers].any?
              safe_join(r[:layers].map { |l|
                link_to "#{l[:slug]} (#{l[:name]})", admin_layer_path(l[:id])
              }, ", ".html_safe)
            else
              content_tag(:em, "unused")
            end
          end
        end
      end
    end

    # ── ra_raster tables ───────────────────────────────────────────────────────
    panel "Raster Tables (ra_raster schema) — #{raster_tables.size} tables" do
      if raster_tables.empty?
        para "No tables found in ra_raster schema."
      else
        table_for raster_tables do
          column("Table name") { |r| r[:name] }
          column("Rows") { |r| number_with_delimiter(r[:row_count]) }
          column("Size") { |r| format_bytes(r[:size_bytes]) }
          column("Used by layers") do |r|
            if r[:layers].any?
              safe_join(r[:layers].map { |l|
                link_to "#{l[:slug]} (#{l[:name]})", admin_layer_path(l[:id])
              }, ", ".html_safe)
            else
              content_tag(:em, "unused")
            end
          end
        end
      end
    end

    # ── S3 COGs ────────────────────────────────────────────────────────────────
    panel "S3 COG Objects (#{ENV.fetch("COG_PREFIX", "cogs/")} prefix)" do
      if svc.s3_error
        div class: "flash flash_error" do
          "S3 not available: #{svc.s3_error}"
        end
      elsif cogs.nil? || cogs.empty?
        para "No COG objects found."
      else
        table_for cogs do
          column("S3 Key") { |r| r[:key] }
          column("Size") { |r| format_bytes(r[:size_bytes]) }
          column("Used by layers") do |r|
            if r[:layers].any?
              safe_join(r[:layers].map { |l|
                link_to "#{l[:slug]} (#{l[:name]})", admin_layer_path(l[:id])
              }, ", ".html_safe)
            else
              content_tag(:em, "unused")
            end
          end
        end
      end
    end
  end

  controller do
    helper_method :format_bytes

    def format_bytes(bytes)
      return "—" unless bytes&.positive?
      if bytes >= 1.gigabyte
        "#{(bytes.to_f / 1.gigabyte).round(2)} GB"
      elsif bytes >= 1.megabyte
        "#{(bytes.to_f / 1.megabyte).round(1)} MB"
      else
        "#{(bytes.to_f / 1.kilobyte).round(1)} KB"
      end
    end
  end
end
