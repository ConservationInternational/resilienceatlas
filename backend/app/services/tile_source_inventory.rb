class TileSourceInventory
  def self.columns(layer, actor)
    raise CanCan::AccessDenied unless actor.superadmin?
    config = JSON.parse(layer.layer_config.presence || "{}")
    body = config.fetch("body", config)
    source = body.dig("params", "table").presence || body["source"]
    return [] unless layer.layer_provider == "martin" && source.is_a?(String)
    sql = ActiveRecord::Base.sanitize_sql_array([
      "SELECT column_name, data_type FROM information_schema.columns WHERE table_schema = 'ra_vector' AND table_name = ? ORDER BY ordinal_position LIMIT 100", source
    ])
    ActiveRecord::Base.connection.select_all(sql).to_a
  rescue JSON::ParserError
    Rails.logger.warn "[TileSourceInventory] Invalid configuration for layer #{layer.id}"
    []
  end

  def self.orphans(actor)
    raise CanCan::AccessDenied unless actor.superadmin?
    referenced = Layer.where(layer_provider: "martin").filter_map do |layer|
      config = JSON.parse(layer.layer_config.presence || "{}")
      body = config.fetch("body", config)
      body.dig("params", "table").presence || body["source"]
    rescue JSON::ParserError
      Rails.logger.warn "[TileSourceInventory] Invalid configuration for layer #{layer.id}"
      nil
    end
    tables = ActiveRecord::Base.connection.select_values(
      "SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'ra_vector' AND c.relkind IN ('r','v','m') ORDER BY c.relname LIMIT 1000"
    )
    tables - referenced
  end
end
