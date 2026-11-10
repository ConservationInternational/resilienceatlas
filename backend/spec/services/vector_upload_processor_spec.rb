require "rails_helper"
require "tmpdir"

RSpec.describe VectorUploadProcessor do
  let(:data_import) do
    double("DataImport", id: 42, options: {}, save!: true).tap do |record|
      allow(record).to receive(:options=) { |value| allow(record).to receive(:options).and_return(value) }
    end
  end
  let(:path) { Rails.root.join("spec/fixtures/files/vector_upload.geojson") }
  let(:conn) { double("connection") }

  before do
    allow(UploadCommand).to receive(:run).and_return(layer_listing, layer_details)
    allow(ActiveRecord::Base).to receive(:connection).and_return(conn)
    allow(ActiveRecord::Base).to receive(:connection_db_config).and_return(
      double(configuration_hash: {host: "db", port: 5432, database: "atlas", username: "atlas", password: "secret"})
    )
    allow(conn).to receive(:execute)
    allow(conn).to receive(:quote) { |value| "'#{value}'" }
    allow(conn).to receive(:quote_table_name) { |value| %("#{value}") }
    allow(conn).to receive(:quote_column_name) { |value| %("#{value}") }
    allow(conn).to receive(:exec_query).and_return(
      [{"f_geometry_column" => "geom"}],
      [{"f_geometry_column" => "geom"}],
      [{"column_name" => "name"}]
    )
    allow(conn).to receive(:select_one).and_return(
      {"rows" => 1, "geometry_rows" => 1, "geometry_type" => "ST_MultiLineString", "bounds" => "BOX(1 2,3 4)"}
    )
    allow(conn).to receive(:select_value).and_return(false, 128)
    allow(VectorGeometryRepair).to receive(:repair_table!).and_return(antimeridian: 0, invalid: 0, skipped: 0)
    allow(LayerInteractionConfigBuilder).to receive(:for_martin).and_return(
      {"output" => [{"column" => "name", "property" => "Name"}]}
    )
  end

  let(:layer_listing) { "INFO: Open of `#{path}' using driver `GeoJSON' successful.\n1: roads (Line String)\n" }
  let(:layer_details) do
    <<~INFO
      Layer name: roads
      Geometry: Line String
      Feature Count: 1
      Extent: (1, 2) - (3, 4)
      Layer SRS WKT:
      GEOGCRS["WGS 84",ID["EPSG",4326]]
      Data axis mapping: 2,1
        name: String (0.0)
    INFO
  end

  it "imports into a new table and returns verified vector metadata" do
    processor = described_class.new(data_import, work_dir: path.dirname, storage: double("storage"))
    expect(UploadCommand).to receive(:run).with(
      "ogrinfo", "-ro", path.to_s
    ).ordered.and_return(layer_listing)
    expect(UploadCommand).to receive(:run).with(
      "ogrinfo", "-ro", "-so", path.to_s, "roads"
    ).ordered.and_return(layer_details)
    expect(UploadCommand).to receive(:run) do |*argv, **options|
      expect(argv).to include("-nln", a_string_matching(/\Ara_vector\.imported_42_[0-9a-f]{16}\z/))
      expect(argv).not_to include("-overwrite")
      expect(options).to include(env: {"PGPASSWORD" => "secret"})
      ""
    end.ordered

    result = processor.call(path)

    expect(result).to include(
      "table" => a_string_matching(/\Aimported_42_[0-9a-f]{16}\z/),
      "bounds" => [1.0, 2.0, 3.0, 4.0],
      "rows" => 1,
      "geometry_type" => "MultiLineString",
      "fields" => ["name"],
      "warnings" => [],
      "interaction_config" => {"output" => [{"column" => "name", "property" => "Name"}]},
      "sublayers" => ["roads"]
    )
    expect(data_import.options).to include("source_crs" => "EPSG:4326", "sublayer" => "roads")
  end

  it "requires a sublayer choice when multiple spatial layers are discovered" do
    allow(UploadCommand).to receive(:run).and_return(
      "1: roads (Line String)\n2: rivers (Line String)\n",
      layer_details,
      layer_details.sub("Layer name: roads", "Layer name: rivers")
    )

    expect {
      described_class.new(data_import, work_dir: path.dirname, storage: double("storage")).call(path)
    }.to raise_error(UploadSelectionRequired, "Choose a spatial layer to import") { |error|
      expect(error.metadata).to eq("sublayers" => %w[roads rivers], "source_crs_required" => false)
    }
    expect(UploadCommand).to have_received(:run).exactly(3).times
  end

  it "requires an explicit EPSG source CRS when layer inspection finds none" do
    data_import.options = {"sublayer" => "roads"}
    allow(UploadCommand).to receive(:run).and_return(
      layer_listing,
      layer_details.sub('GEOGCRS["WGS 84",ID["EPSG",4326]]', "")
    )

    expect {
      described_class.new(data_import, work_dir: path.dirname, storage: double("storage")).call(path)
    }.to raise_error(UploadSelectionRequired, "Choose a source CRS before importing this dataset") { |error|
      expect(error.metadata).to eq("sublayers" => ["roads"], "source_crs_required" => true)
    }
    expect(UploadCommand).to have_received(:run).exactly(2).times
  end

  it "rejects a non-EPSG source CRS selection" do
    data_import.options = {"sublayer" => "roads", "source_crs" => "EPSG:4326; DROP TABLE"}
    allow(UploadCommand).to receive(:run).and_return(layer_listing, layer_details)

    expect {
      described_class.new(data_import, work_dir: path.dirname, storage: double("storage")).call(path)
    }.to raise_error(ArgumentError, "Source CRS must be an explicit EPSG code")
  end

  it "recognizes a valid custom WKT CRS even when it has no EPSG identifier" do
    details = <<~INFO
      Geometry: Point
      Layer SRS WKT:
      LOCAL_CS["custom local CRS",LOCAL_DATUM["custom datum",0],
        GEOGCS["WGS 84",AUTHORITY["EPSG","4326"]],
        UNIT["metre",1],AXIS["Easting",EAST],AXIS["Northing",NORTH]]
    INFO

    layer = described_class.new(data_import, work_dir: path.dirname, storage: double("storage"))
      .send(:parse_layer_details, "custom", "Point", details)

    expect(layer).to include(epsg: nil, crs_present: true)
  end

  it "rejects ZIP entries that attempt path traversal" do
    Dir.mktmpdir("vector-upload-zip-") do |dir|
      work_dir = Pathname.new(dir)
      archive_path = work_dir.join("traversal.zip")
      Zip::OutputStream.open(archive_path.to_s) do |zip|
        zip.put_next_entry("../roads.shp")
        zip.write("not a shapefile")
      end

      processor = described_class.new(data_import, work_dir: work_dir, storage: double("storage"))
      expect {
        processor.send(:extract_shapefile_archive, archive_path)
      }.to raise_error(ArgumentError, "ZIP upload contains a path traversal")
    end
  end
end

RSpec.describe VectorUploadProcessor, "with real GDAL and PostGIS" do
  self.use_transactional_tests = false

  let(:conn) { ActiveRecord::Base.connection }
  let(:work_dir) { Rails.root.join("tmp/vector-upload-integration-spec") }

  before do
    FileUtils.mkdir_p(work_dir)
    with_database_connection do |database|
      database.exec("CREATE SCHEMA IF NOT EXISTS ra_vector")
    end
  end

  after do
    with_database_connection do |database|
      imported_tables.each do |table|
        database.exec("DROP TABLE IF EXISTS ra_vector.#{PG::Connection.quote_ident(table)}")
      end
    end
    FileUtils.rm_rf(work_dir)
  end

  let(:imported_tables) { @imported_tables ||= [] }

  def run_import(path, id:)
    data_import = double("DataImport", id: id, options: {}, save!: true)
    allow(data_import).to receive(:options=) { |value| allow(data_import).to receive(:options).and_return(value) }
    metadata = described_class.new(
      data_import,
      work_dir: work_dir,
      storage: double("storage")
    ).call(path)
    imported_tables << metadata.fetch("table")
    metadata
  end

  it "discovers and imports the GeoJSON fixture and produces a usable vector tile" do
    metadata = run_import(Rails.root.join("spec/fixtures/files/vector_upload.geojson"), id: 501)

    expect(metadata).to include(
      "bounds" => [1.0, 2.0, 3.0, 4.0],
      "rows" => 1,
      "geometry_type" => "MultiLineString",
      "fields" => ["name"],
      "sublayers" => ["roads"]
    )
    expect(conn.select_value(mvt_query(metadata.fetch("table"))).to_i).to be > 0
  end

  it "uses the root EPSG code from a projected GeoPackage and transforms bounds to WGS84" do
    source_path = Rails.root.join("spec/fixtures/files/vector_upload.geojson")
    gpkg_path = work_dir.join("projected.geojson.gpkg")
    UploadCommand.run("ogr2ogr", "-f", "GPKG", "-t_srs", "EPSG:3857", gpkg_path.to_s, source_path.to_s)

    data_import = double("DataImport", id: 502, options: {}, save!: true)
    allow(data_import).to receive(:options=) { |value| allow(data_import).to receive(:options).and_return(value) }
    metadata = described_class.new(
      data_import,
      work_dir: work_dir,
      storage: double("storage")
    ).call(gpkg_path)
    imported_tables << metadata.fetch("table")

    expect(data_import.options).to include("source_crs" => "EPSG:3857", "sublayer" => "roads")
    bounds = metadata.fetch("bounds")
    [1.0, 2.0, 3.0, 4.0].each_with_index do |expected, index|
      expect(bounds[index]).to be_within(0.00001).of(expected)
    end
    expect(conn.select_value(mvt_query(metadata.fetch("table"))).to_i).to be > 0
  end

  it "imports point and multipolygon GeoJSON with real GDAL metadata and MVT validation" do
    datasets = {
      "point" => {
        "type" => "Point",
        "coordinates" => [5, 6]
      },
      "polygon" => {
        "type" => "Polygon",
        "coordinates" => [[[10, 10], [12, 10], [12, 12], [10, 12], [10, 10]]]
      },
      "multipolygon" => {
        "type" => "MultiPolygon",
        "coordinates" => [
          [[[20, 20], [22, 20], [22, 22], [20, 22], [20, 20]]],
          [[[24, 24], [26, 24], [26, 26], [24, 26], [24, 24]]]
        ]
      }
    }

    datasets.each do |name, geometry|
      path = work_dir.join("#{name}.geojson")
      File.write(path, {
        type: "FeatureCollection",
        name: name,
        features: [{
          type: "Feature",
          properties: {name: name},
          geometry: geometry
        }]
      }.to_json)
      metadata = run_import(path, id: name.hash.abs % 10_000 + 600)

      expect(metadata.fetch("rows")).to eq(1)
      expect(metadata.fetch("fields")).to include("name")
      expect(metadata.fetch("geometry_type")).to match(/\AMulti(?:Point|Polygon)\z/)
      expect(conn.select_value(mvt_query(metadata.fetch("table"))).to_i).to be > 0
    end
  end

  def with_database_connection
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    database = PG.connect(
      host: config[:host],
      port: config[:port],
      dbname: config[:database],
      user: config[:username],
      password: config[:password]
    )
    yield database
  ensure
    database&.close
  end

  def mvt_query(table)
    quoted_table = "#{conn.quote_table_name("ra_vector")}.#{conn.quote_table_name(table)}"
    <<~SQL.squish
      SELECT octet_length(ST_AsMVT(tile_rows, 'upload', 4096, 'mvtgeom'))
      FROM (
        SELECT ST_AsMVTGeom(ST_Transform(geom, 3857), ST_TileEnvelope(0, 0, 0), 4096, 256, true) AS mvtgeom
        FROM #{quoted_table}
        WHERE geom IS NOT NULL
      ) tile_rows
      WHERE mvtgeom IS NOT NULL
    SQL
  end
end
