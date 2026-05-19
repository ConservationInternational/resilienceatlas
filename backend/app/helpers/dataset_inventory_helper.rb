module DatasetInventoryHelper
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

  def sort_link(label, col, current_sort, current_dir, base_params)
    new_dir = (current_sort == col && current_dir == "asc") ? "desc" : "asc"
    arrow = current_sort == col ? (current_dir == "asc" ? " ▲" : " ▼") : ""
    link_to "#{label}#{arrow}".html_safe,
      admin_dataset_inventory_path(base_params.merge(sort: col, dir: new_dir, page: 1))
  end

  def inventory_pagination(result, base_params)
    total = result[:total]
    cur   = result[:page]
    per   = result[:per_page]
    return "".html_safe if total <= per

    total_pages = (total.to_f / per).ceil
    parts = []
    parts << link_to("← Prev", admin_dataset_inventory_path(base_params.merge(page: cur - 1))) if cur > 1

    window = (([cur - 2, 1].max)..([cur + 2, total_pages].min)).to_a
    parts << link_to("1", admin_dataset_inventory_path(base_params.merge(page: 1))) if window.first > 1
    parts << content_tag(:span, "…") if window.first > 2

    window.each do |p|
      parts << (p == cur ? content_tag(:strong, p) : link_to(p, admin_dataset_inventory_path(base_params.merge(page: p))))
    end

    parts << content_tag(:span, "…") if window.last < total_pages - 1
    parts << link_to(total_pages, admin_dataset_inventory_path(base_params.merge(page: total_pages))) if window.last < total_pages
    parts << link_to("Next →", admin_dataset_inventory_path(base_params.merge(page: cur + 1))) if cur < total_pages

    from = (cur - 1) * per + 1
    to   = [cur * per, total].min
    content_tag(:div, class: "inventory-pagination") do
      safe_join([
        safe_join(parts, " "),
        content_tag(:br),
        content_tag(:small, "Showing #{number_with_delimiter(from)}–#{number_with_delimiter(to)} of #{number_with_delimiter(total)}")
      ])
    end
  end

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
