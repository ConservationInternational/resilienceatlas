require "rails_helper"

RSpec.describe VectorGeometryRepair do
  let(:conn) { ActiveRecord::Base.connection }
  let(:schema) { "vector_geometry_repair_spec" }
  let(:table) { "polygons" }
  let(:roundoff_wkt) do
    "MULTIPOLYGON(((170.123456789123 -45,180.00000009160476 -45," \
      "180.00000009160476 -35,170.123456789123 -35,170.123456789123 -45)," \
      "(172 -44,172 -43,173 -43,173 -44,172 -44))," \
      "((-180.00000000007876 -25,-170 -25,-170 -15,-180.00000000007876 -15,-180.00000000007876 -25)))"
  end

  before do
    conn.execute("CREATE SCHEMA #{schema}")
    conn.execute("CREATE TABLE #{schema}.#{table} (name text, geom geometry(MultiPolygon, 4326))")
    {
      "unsplit" => "POLYGON((170 -10,-170 -10,-170 10,170 10,170 -10))",
      "mixed" => "MULTIPOLYGON(((179 1,-179 1,-179 2,179 2,179 1)),((10 10,11 10,11 11,10 11,10 10)))",
      "presplit" => "MULTIPOLYGON(((170 -10,180 -10,180 10,170 10,170 -10)),((-180 -10,-170 -10,-170 10,-180 10,-180 -10)))",
      "pacific_islands" => "MULTIPOLYGON(((150 0,151 0,151 1,150 1,150 0)),((-150 0,-149 0,-149 1,-150 1,-150 0)))",
      "antarctica" => "POLYGON((-180 -89,-180 -70,-90 -65,0 -70,90 -65,180 -70,180 -89,-180 -89))",
      "bowtie" => "POLYGON((0 0,1 1,1 0,0 1,0 0))"
    }.each do |name, wkt|
      conn.execute(
        "INSERT INTO #{schema}.#{table} VALUES " \
        "(#{conn.quote(name)}, ST_Multi(ST_GeomFromText(#{conn.quote(wkt)}, 4326)))"
      )
    end
    conn.execute("CREATE TABLE #{schema}.originals AS SELECT * FROM #{schema}.#{table}")
  end

  def row(name)
    conn.select_one(
      "SELECT ST_IsValid(t.geom) AS valid, ST_AsBinary(t.geom) = ST_AsBinary(o.geom) AS unchanged, " \
      "ST_Area(t.geom) AS area, " \
      "(SELECT max(ST_XMax(d.geom) - ST_XMin(d.geom)) FROM ST_Dump(t.geom) d) AS max_part_width " \
      "FROM #{schema}.#{table} t JOIN #{schema}.originals o USING (name) " \
      "WHERE t.name = #{conn.quote(name)}"
    )
  end

  shared_examples "a geometry repair" do |batch_size|
    it "splits antimeridian-crossing polygons and repairs invalid ones without touching other geometries" do
      result = described_class.repair_table!(conn, schema: schema, table: table, batch_size: batch_size)

      expect(result).to eq(antimeridian: 2, invalid: 1, skipped: 0)

      expect(row("unsplit")).to include("valid" => true, "unchanged" => false, "max_part_width" => 10.0)
      expect(row("unsplit")["area"]).to be_within(1e-6).of(400)
      expect(row("mixed")).to include("valid" => true, "max_part_width" => 1.0)
      expect(row("mixed")["area"]).to be_within(1e-6).of(3)

      %w[presplit pacific_islands antarctica].each do |name|
        expect(row(name)).to include("unchanged" => true)
      end

      expect(row("bowtie")["valid"]).to be(true)
    end

    it "is idempotent" do
      described_class.repair_table!(conn, schema: schema, table: table, batch_size: batch_size)

      expect(described_class.repair_table!(conn, schema: schema, table: table, batch_size: batch_size))
        .to eq(antimeridian: 0, invalid: 0, skipped: 0)
    end

    it "clamps longitude roundoff without changing other coordinates or holes, eliminating projected bands" do
      conn.execute("TRUNCATE #{schema}.#{table}")
      conn.execute("INSERT INTO #{schema}.#{table} VALUES ('roundoff', ST_GeomFromText(#{conn.quote(roundoff_wkt)}, 4326))")
      projected_width = "SELECT max(ST_XMax(d.geom) - ST_XMin(d.geom)) " \
        "FROM #{schema}.#{table}, ST_Dump(ST_Transform(geom, 3857)) d"
      atlantic_tile = "SELECT ST_AsMVTGeom(ST_Transform(geom, 3857), ST_TileEnvelope(2, 1, 2), 4096, 256, true) IS NULL " \
        "FROM #{schema}.#{table}"
      expect(conn.select_value(projected_width)).to be > 38_000_000
      expect(conn.select_value(atlantic_tile)).to be(false)

      expect(described_class.repair_table!(conn, schema: schema, table: table, checks: [:antimeridian], batch_size: batch_size))
        .to eq(antimeridian: 1, invalid: 0, skipped: 0)

      expected = roundoff_wkt.gsub("180.00000009160476", "180").gsub("-180.00000000007876", "-180")
      expect(conn.select_one(
        "SELECT ST_AsEWKB(geom) = ST_AsEWKB(ST_GeomFromText(#{conn.quote(expected)}, 4326)) AS exact_match, " \
        "ST_AsEWKT(geom) AS actual FROM #{schema}.#{table}"
      )).to include("exact_match" => true)
      expect(conn.select_value(projected_width)).to be < 1_200_000
      expect(conn.select_value(atlantic_tile)).to be(true)
      expect(described_class.repair_table!(conn, schema: schema, table: table, checks: [:antimeridian], batch_size: batch_size))
        .to eq(antimeridian: 0, invalid: 0, skipped: 0)
    end
  end

  it_behaves_like "a geometry repair", nil
  it_behaves_like "a geometry repair", 1
  it_behaves_like "a geometry repair", 500

  it "preserves a generic column's Polygon type and Z coordinates when clamping longitude" do
    conn.execute("ALTER TABLE #{schema}.#{table} ALTER COLUMN geom TYPE geometry(GeometryZ, 4326) USING ST_Force3D(geom)")
    conn.execute("TRUNCATE #{schema}.#{table}")
    wkt = "POLYGON Z((170 -45 1,180.00000009160476 -45 2,180.00000009160476 -35 3,170 -35 4,170 -45 1))"
    conn.execute("INSERT INTO #{schema}.#{table} VALUES ('roundoff', ST_GeomFromText(#{conn.quote(wkt)}, 4326))")

    expect(described_class.repair_table!(conn, schema: schema, table: table, checks: [:antimeridian]))
      .to eq(antimeridian: 1, invalid: 0, skipped: 0)
    expected = wkt.gsub("180.00000009160476", "180")
    expect(conn.select_one(
      "SELECT ST_AsEWKB(geom) = ST_AsEWKB(ST_GeomFromText(#{conn.quote(expected)}, 4326)) AS exact_match, " \
      "ST_AsEWKT(geom) AS actual FROM #{schema}.#{table}"
    )).to include("exact_match" => true)
  end

  it "does not clamp genuinely out-of-range longitudes or round in-range coordinates" do
    conn.execute("TRUNCATE #{schema}.#{table}")
    %w[180.001 179.99999999987392].each do |longitude|
      wkt = "MULTIPOLYGON(((170 -45,#{longitude} -45,#{longitude} -35,170 -35,170 -45)))"
      conn.execute("INSERT INTO #{schema}.#{table} VALUES (#{conn.quote(longitude)}, ST_GeomFromText(#{conn.quote(wkt)}, 4326))")
    end
    expect(described_class.repair_table!(conn, schema: schema, table: table, checks: [:antimeridian]))
      .to eq(antimeridian: 0, invalid: 0, skipped: 0)
  end

  it "normalizes rounding overshoots in a typed Polygon column" do
    conn.execute("TRUNCATE #{schema}.#{table}")
    conn.execute("ALTER TABLE #{schema}.#{table} ALTER COLUMN geom TYPE geometry(Polygon, 4326)")
    conn.execute(
      "INSERT INTO #{schema}.#{table} VALUES ('roundoff', " \
      "ST_GeomFromText('POLYGON((170 -45,180.00000009160476 -45,180.00000009160476 -35,170 -35,170 -45))', 4326))"
    )
    expect(described_class.repair_table!(conn, schema: schema, table: table, checks: [:antimeridian], batch_size: 500))
      .to eq(antimeridian: 1, invalid: 0, skipped: 0)
    expect(conn.select_value("SELECT ST_XMax(geom) FROM #{schema}.#{table}")).to eq(180)
  end

  context "when a row crashes the database backend" do
    let(:poison_ctid) { conn.select_value("SELECT ctid::text FROM #{schema}.#{table} WHERE name = 'bowtie'") }

    before do
      allow(conn).to receive(:exec_update).and_wrap_original do |original, sql, *args|
        if sql.include?("'#{poison_ctid}'") && sql.include?("ST_MakeValid(\"geom\")")
          raise ActiveRecord::ConnectionFailed, "PQconsumeInput() server closed the connection unexpectedly"
        end

        original.call(sql, *args)
      end
    end

    it "retries the batch row by row and skips only the crashing row" do
      crashes = []
      result = described_class.repair_table!(
        conn, schema: schema, table: table, batch_size: 500,
        on_crash: lambda do |e|
          crashes << e
          conn
        end
      )

      expect(result).to eq(antimeridian: 2, invalid: 0, skipped: 1)
      expect(crashes.size).to eq(2)
      expect(row("bowtie")).to include("valid" => false, "unchanged" => true)
      expect(row("unsplit")["max_part_width"]).to eq(10.0)
    end

    it "gives up after max_crashes" do
      expect {
        described_class.repair_table!(
          conn, schema: schema, table: table, batch_size: 500, max_crashes: 1, on_crash: ->(_e) { conn }
        )
      }.to raise_error(VectorGeometryRepair::TooManyCrashes)
    end

    it "propagates the error without on_crash" do
      expect {
        described_class.repair_table!(conn, schema: schema, table: table, batch_size: 500)
      }.to raise_error(ActiveRecord::ConnectionFailed)
    end
  end
end
