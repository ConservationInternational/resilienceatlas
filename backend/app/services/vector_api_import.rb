require "tmpdir"

class VectorApiImport
  ImportContext = Struct.new(:id, :options)

  def initialize(s3_uri, table_name, options: {})
    @uri = URI(s3_uri)
    @table_name = table_name
    @options = options
  end

  def call
    storage = UploadStorage.new
    raise ArgumentError, "Import must use the configured upload bucket" unless @uri.host == storage.bucket
    conn = ActiveRecord::Base.connection
    schema = DatasetInventoryService::VECTOR_SCHEMA
    existing = conn.select_value("SELECT to_regclass(#{conn.quote("#{schema}.#{@table_name}")})")
    raise ArgumentError, "Table already exists. Use the upload workspace for a validated replacement." if existing
    key = @uri.path.delete_prefix("/")
    size = storage.head(key).content_length
    raise ArgumentError, "File size exceeds the upload limit" unless size.between?(1, SpatialUploadLifecycle.max_bytes)
    metadata = nil
    Dir.mktmpdir("vector-api-", Rails.root.join("tmp")) do |dir|
      path = File.join(dir, File.basename(key))
      storage.download(key, path)
      context = ImportContext.new(SecureRandom.hex(6), @options)
      metadata = VectorUploadProcessor.new(context, work_dir: Pathname(dir), storage: storage).call(path)
    end
    conn.transaction do
      conn.execute("ALTER TABLE #{conn.quote_table_name(schema)}.#{conn.quote_table_name(metadata.fetch("table"))} RENAME TO #{conn.quote_table_name(@table_name)}")
    end
    DatasetInventoryService.invalidate_all_caches!
    columns = conn.columns("#{schema}.#{@table_name}").index_by(&:name)
    {table_name: @table_name, schema: schema, row_count: metadata.fetch("rows"),
     geometry_type: metadata.fetch("geometry_type"), srid: 4326, bounds: metadata.fetch("bounds"),
     columns: metadata.fetch("fields").map { |field| {name: field, type: columns.fetch(field).sql_type} }}
  end
end
