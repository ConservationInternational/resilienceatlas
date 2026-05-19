ActiveAdmin.register_page "Dataset Table Viewer" do
  menu false

  content title: "Table Viewer" do
    div class: "inventory-about" do
      para "Read-only paginated view of a PostGIS table. Rows are fetched directly from the database; large tables are paged at 50 rows per page. Use the back link to return to the Dataset Inventory."
    end

    schema     = params[:schema].presence
    table_name = params[:table].presence
    page       = [params[:page].to_i, 1].max
    per_page   = 50

    back_section = schema == DatasetInventoryService::RASTER_SCHEMA ? "raster" : "vector"

    div class: "inventory-breadcrumb" do
      link_to "← Back to Dataset Inventory",
        admin_dataset_inventory_path(section: back_section)
    end

    if schema.blank? || table_name.blank?
      panel "No table specified" do
        para "Please navigate here from the Dataset Inventory page."
      end
    else
      svc    = DatasetInventoryService.new
      result = svc.table_data(schema, table_name, page: page, per_page: per_page)

      if result.nil?
        panel "Error" do
          div class: "flash flash_error" do
            svc.table_data_error || "Table not found or access denied."
          end
        end
      else
        panel "#{schema}.#{table_name} — #{number_with_delimiter(result[:total])} rows" do
          if result[:rows].empty?
            para "No rows found."
          else
            div style: "overflow-x: auto;" do
              table class: "inventory-table" do
                thead do
                  tr do
                    result[:columns].each { |col| th col }
                  end
                end
                tbody do
                  result[:rows].each do |row|
                    tr do
                      row.each do |val|
                        td do
                          text_node truncate(val.to_s, length: 120)
                        end
                      end
                    end
                  end
                end
              end
            end

            text_node table_viewer_pagination(result, schema, table_name)
          end
        end
      end
    end
  end

  controller do
    helper DatasetInventoryHelper
  end
end
