ActiveAdmin.register_page "Dataset Table Viewer" do
  menu false

  content title: "Table Viewer" do
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
    helper_method :table_viewer_pagination

    def table_viewer_pagination(result, schema, table_name)
      total = result[:total]
      cur   = result[:page]
      per   = result[:per_page]
      return "".html_safe if total <= per

      total_pages = (total.to_f / per).ceil
      base = {schema: schema, table: table_name}
      parts = []
      parts << link_to("← Prev", admin_dataset_table_viewer_path(base.merge(page: cur - 1))) if cur > 1

      window = (([cur - 2, 1].max)..([cur + 2, total_pages].min)).to_a
      parts << link_to("1", admin_dataset_table_viewer_path(base.merge(page: 1))) if window.first > 1
      parts << content_tag(:span, "…") if window.first > 2

      window.each do |p|
        parts << (p == cur ? content_tag(:strong, p) : link_to(p, admin_dataset_table_viewer_path(base.merge(page: p))))
      end

      parts << content_tag(:span, "…") if window.last < total_pages - 1
      parts << link_to(total_pages, admin_dataset_table_viewer_path(base.merge(page: total_pages))) if window.last < total_pages
      parts << link_to("Next →", admin_dataset_table_viewer_path(base.merge(page: cur + 1))) if cur < total_pages

      from = (cur - 1) * per + 1
      to   = [cur * per, total].min
      content_tag(:div, class: "inventory-pagination") do
        safe_join([
          safe_join(parts, " "),
          content_tag(:br),
          content_tag(:small, "Showing #{number_with_delimiter(from)}–#{number_with_delimiter(to)} of #{number_with_delimiter(total)} rows")
        ])
      end
    end
  end
end
