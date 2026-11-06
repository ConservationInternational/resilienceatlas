require "rails_helper"

RSpec.describe VectorGeometryRepair do
  let(:conn) { ActiveRecord::Base.connection }
  let(:schema) { "vector_geometry_repair_spec" }
  let(:table) { "polygons" }

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

      expect(result).to eq(antimeridian: 2, invalid: 1)

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
        .to eq(antimeridian: 0, invalid: 0)
    end
  end

  it_behaves_like "a geometry repair", nil
  it_behaves_like "a geometry repair", 1
end
