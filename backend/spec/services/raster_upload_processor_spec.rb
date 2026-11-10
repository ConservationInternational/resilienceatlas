require "spec_helper"
require "ostruct"
require "open3"
require "tmpdir"
require_relative "../../app/services/upload_command"
require_relative "../../app/services/raster_upload_processor"

RSpec.describe RasterUploadProcessor do
  let(:data_import) { OpenStruct.new(id: 42, import_type: "cog", options: {"raster_kind" => "continuous"}, metadata: {"existing" => true}) }
  let(:storage) { double("storage", bucket: "rasters") }
  let(:work_dir) { Pathname.new(Dir.mktmpdir("raster-work-")) }
  let(:source_path) { work_dir.join("source ; not a command.tif") }
  let(:processor) { described_class.new(data_import, work_dir: work_dir, storage: storage) }
  let(:input_info) do
    {
      "driverShortName" => "GTiff",
      "size" => [32, 16],
      "geoTransform" => [-10, 0.1, 0, 10, 0, -0.1],
      "coordinateSystem" => {"wkt" => "EPSG:4326 WKT"},
      "wgs84Extent" => {"coordinates" => [[[-10, 10], [-10, 8.4], [-6.8, 8.4], [-6.8, 10], [-10, 10]]]},
      "bands" => [{
        "band" => 1, "type" => "Int16", "noDataValue" => -32768,
        "colorInterpretation" => "Gray",
        "metadata" => {"" => {"STATISTICS_VALID_PERCENT" => "95"}}
      }]
    }
  end
  let(:output_info) { Marshal.load(Marshal.dump(input_info)).merge("metadata" => {"IMAGE_STRUCTURE" => {"LAYOUT" => "COG"}}) }
  let(:commands) { [] }

  before do
    File.write(source_path, "input raster")
    allow(UploadCommand).to receive(:run) do |*argv, **kwargs|
      commands << [argv, kwargs]
      if argv.first == "gdal_translate"
        File.write(argv.last, "converted raster")
        ""
      elsif argv.last == source_path.to_s
        JSON.generate(input_info)
      elsif argv.last.end_with?(".vrt")
        JSON.generate(input_info.merge("driverShortName" => "VRT", "coordinateSystem" => {"wkt" => "EPSG:4326 WKT"}))
      else
        JSON.generate(output_info)
      end
    end
    allow(storage).to receive(:upload_file)
    allow(storage).to receive(:head).and_return(content_length: "converted raster".bytesize)
  end

  after { FileUtils.rm_rf(work_dir) }

  it "returns string-keyed immutable artifact metadata without modifying the import" do
    result = processor.call(source_path)
    expect(result).to include(
      "bounds" => [-10, 8.4, -6.8, 10], "bands" => output_info["bands"],
      "driver" => "GTiff", "crs" => "EPSG:4326 WKT", "warnings" => []
    )
    expect(result["output_key"]).to match(%r{\Acogs/imports/42/[0-9a-f-]+\.tif\z})
    expect(result["source"]).to eq("s3://rasters/#{result["output_key"]}")
    expect(result.keys).to all(be_a(String))
    expect(storage).to have_received(:upload_file).with(anything, result["output_key"], content_type: "image/tiff")
    expect(data_import.metadata).to eq("existing" => true)
  end

  it "uses safe argv, bounded GDAL resources, lossless compression, and average overviews" do
    allow(Timeout).to receive(:timeout).and_call_original
    processor.call(source_path)
    argv, kwargs = commands.find { |args, _| args.first == "gdal_translate" }
    expect(argv).to include(source_path.to_s, "COG", "COMPRESS=DEFLATE", "OVERVIEWS=IGNORE_EXISTING", "RESAMPLING=AVERAGE")
    expect(argv).not_to include("-ot", "-scale", "-a_nodata")
    expect(Timeout).to have_received(:timeout).with(be_between(0, 1800)).at_least(:once)
    expect(kwargs[:env]).to include("GDAL_CACHEMAX" => "128", "GDAL_NUM_THREADS" => "2")
  end

  it "uses nearest-neighbor overviews for categorical data" do
    data_import.options = {"raster_kind" => "categorical"}
    processor.call(source_path)
    expect(commands.find { |args, _| args.first == "gdal_translate" }.first).to include("RESAMPLING=NEAREST")
  end

  it "uses nearest-neighbor overviews for palette data" do
    input_info["bands"][0]["colorTable"] = {"palette" => "RGB", "entries" => [[0, 0, 0, 0]]}
    processor.call(source_path)
    expect(commands.find { |args, _| args.first == "gdal_translate" }.first).to include("RESAMPLING=NEAREST")
  end

  it "uses average overviews for RGB rasters" do
    data_import.options = {"raster_kind" => "rgb"}
    processor.call(source_path)
    expect(commands.find { |args, _| args.first == "gdal_translate" }.first).to include("RESAMPLING=AVERAGE")
  end

  it "warns when raster semantics were not specified" do
    data_import.options = {}
    expect(processor.call(source_path)["warnings"].join).to include("continuous with average overviews")
  end

  it "rejects unknown raster kinds before invoking GDAL" do
    data_import.options = {"raster_kind" => "unknown"}
    expect { processor.call(source_path) }.to raise_error(described_class::Error, /raster_kind/)
    expect(UploadCommand).not_to have_received(:run)
  end

  it "rejects missing input files" do
    File.delete(source_path)
    expect { processor.call(source_path) }.to raise_error(described_class::Error, /missing or empty/)
  end

  it "rejects non-raster imports" do
    data_import.import_type = "vector"
    expect { processor.call(source_path) }.to raise_error(described_class::Error, /COG import/)
  end

  it "generates a different artifact key on retries" do
    expect(processor.call(source_path)["output_key"]).not_to eq(processor.call(source_path)["output_key"])
  end

  {
    "non-GeoTIFF input" => ->(info) { info["driverShortName"] = "PNG" },
    "empty dimensions" => ->(info) { info["size"] = [0, 16] },
    "absent georeferencing" => ->(info) { info.delete("geoTransform") },
    "degenerate georeferencing" => ->(info) { info["geoTransform"] = [0, 0, 0, 0, 0, 0] },
    "absent bands" => ->(info) { info["bands"] = [] },
    "all-nodata band" => ->(info) { info["bands"][0]["metadata"][""]["STATISTICS_VALID_PERCENT"] = "0" },
    "invalid nodata" => ->(info) { info["bands"][0]["noDataValue"] = "not a number" },
    "missing geographic bounds" => ->(info) { info.delete("wgs84Extent") },
    "invalid geographic bounds" => ->(info) { info["wgs84Extent"]["coordinates"][0][0] = [200, 95] }
  }.each do |name, change|
    it "rejects #{name} without uploading" do
      change.call(input_info)
      expect { processor.call(source_path) }.to raise_error(described_class::Error)
      expect(storage).not_to have_received(:upload_file)
    end
  end

  it "rejects missing CRS without an explicit EPSG override" do
    input_info.delete("coordinateSystem")
    expect { processor.call(source_path) }.to raise_error(described_class::Error, /explicit EPSG/)
  end

  it "rejects non-EPSG source CRS overrides" do
    input_info.delete("coordinateSystem")
    data_import.options = {"source_crs" => "+proj=longlat"}
    expect { processor.call(source_path) }.to raise_error(described_class::Error, /explicit EPSG/)
  end

  it "assigns an explicit missing CRS without reprojecting pixels" do
    input_info.delete("coordinateSystem")
    data_import.options = {"source_crs" => "EPSG:4326"}
    output_info["coordinateSystem"] = {"wkt" => "EPSG:4326 WKT"}
    result = processor.call(source_path)
    expect(commands.find { |args, _| args.include?("VRT") }.first).to include("-a_srs", "EPSG:4326")
    expect(result["warnings"].join).to include("assigned EPSG:4326")
  end

  it "warns about undefined nodata while preserving masks" do
    input_info["bands"][0].delete("noDataValue")
    input_info["bands"][0]["mask"] = {"flags" => ["PER_DATASET"]}
    expect(processor.call(source_path)["warnings"].join).to include("no explicit nodata")
  end

  {
    "non-COG layout" => ->(info) { info["metadata"]["IMAGE_STRUCTURE"].delete("LAYOUT") },
    "changed dimensions" => ->(info) { info["size"] = [16, 16] },
    "changed band count" => ->(info) { info["bands"] *= 2 },
    "changed nodata" => ->(info) { info["bands"][0]["noDataValue"] = 0 },
    "changed numeric type" => ->(info) { info["bands"][0]["type"] = "Byte" },
    "changed affine transform" => ->(info) { info["geoTransform"][0] = 0 },
    "changed CRS" => ->(info) { info["coordinateSystem"]["wkt"] = "EPSG:3857 WKT" }
  }.each do |name, change|
    it "rejects #{name} before uploading" do
      change.call(output_info)
      expect { processor.call(source_path) }.to raise_error(described_class::Error)
      expect(storage).not_to have_received(:upload_file)
    end
  end

  it "rejects a lost explicit mask" do
    output_info
    input_info["bands"][0]["mask"] = {"flags" => ["PER_DATASET"]}
    expect { processor.call(source_path) }.to raise_error(described_class::Error, /mask/)
  end

  it "rejects a corrupt or incomplete uploaded object" do
    allow(storage).to receive(:head).and_return(content_length: 1)
    expect { processor.call(source_path) }.to raise_error(described_class::Error, /size/)
  end

  it "propagates CLI failures without uploading" do
    allow(UploadCommand).to receive(:run).and_raise("GDAL failed")
    expect { processor.call(source_path) }.to raise_error(/GDAL failed/)
    expect(storage).not_to have_received(:upload_file)
  end

  it "reports malformed GDAL JSON" do
    allow(UploadCommand).to receive(:run).and_return("not JSON")
    expect { processor.call(source_path) }.to raise_error(described_class::Error, /Invalid gdalinfo JSON/)
  end

  it "enforces a total processing deadline" do
    allow(processor).to receive(:monotonic_time).and_return(0, 1801)
    expect { processor.call(source_path) }.to raise_error(described_class::Error, /time budget/)
    expect(UploadCommand).not_to have_received(:run)
  end

  it "reports command timeouts without uploading" do
    allow(UploadCommand).to receive(:run).and_raise(Timeout::Error)
    expect { processor.call(source_path) }.to raise_error(described_class::Error, /time budget/)
    expect(storage).not_to have_received(:upload_file)
  end

  context "with real GDAL", if: ENV["RUN_GDAL_SPECS"] == "1" do
    before do
      allow(UploadCommand).to receive(:run) do |*argv, **kwargs|
        stdout, stderr, status = Open3.capture3(kwargs.fetch(:env, {}), *argv)
        raise stderr unless status.success?

        stdout
      end
      allow(storage).to receive(:upload_file) do |path, _key, **_kwargs|
        allow(storage).to receive(:head).and_return(content_length: File.size(path))
      end
    end

    def create_raster(*extra)
      _stdout, stderr, status = Open3.capture3(
        "gdal_create", "-of", "GTiff", "-outsize", "1024", "512",
        "-a_ullr", "-10", "10", "10", "-10", *extra, source_path.to_s
      )
      raise stderr unless status.success?
    end

    it "preserves signed values, nodata, CRS, and COG layout" do
      create_raster("-ot", "Int16", "-burn", "-123", "-a_nodata", "-32768", "-a_srs", "EPSG:4326")
      result = processor.call(source_path)
      band = result["bands"].first
      expect(band).to include("type" => "Int16", "noDataValue" => -32768, "minimum" => -123.0, "maximum" => -123.0)
      expect(result["bounds"]).to eq([-10, -10, 10, 10])
      expect(band.fetch("overviews")).not_to be_empty
    end

    it "assigns a missing CRS and produces geographic bounds" do
      create_raster("-ot", "Float32", "-burn", "1.25", "-a_nodata", "-9999")
      data_import.options = {"source_crs" => "EPSG:4326"}
      expect(processor.call(source_path)["bounds"]).to eq([-10, -10, 10, 10])
    end

    it "rejects a raster containing only nodata" do
      create_raster("-ot", "Int16", "-burn", "-32768", "-a_nodata", "-32768", "-a_srs", "EPSG:4326")
      expect { processor.call(source_path) }.to raise_error(described_class::Error, /only nodata/)
    end

    it "reports geographic rather than projected bounds" do
      create_raster("-ot", "Byte", "-burn", "123", "-a_srs", "EPSG:3857")
      bounds = processor.call(source_path)["bounds"]
      expect(bounds[0]).to be_within(0.000001).of(-0.0000898)
      expect(bounds[1]).to be_within(0.000001).of(-0.0000898)
      expect(bounds[2]).to be_within(0.000001).of(0.0000898)
      expect(bounds[3]).to be_within(0.000001).of(0.0000898)
    end

    it "preserves floating-point NaN nodata" do
      create_raster("-ot", "Float32", "-burn", "1.25", "-a_nodata", "nan", "-a_srs", "EPSG:4326")
      expect(processor.call(source_path)["bands"].first).to include("noDataValue" => "NaN", "minimum" => 1.25)
    end

    it "does not invent categorical values in overviews" do
      create_raster("-ot", "Byte", "-burn", "1", "-a_srs", "EPSG:4326")
      _stdout, stderr, status = Open3.capture3(
        "python3", "-c",
        "from osgeo import gdal; import sys; d=gdal.Open(sys.argv[1], gdal.GA_Update); " \
        "d.GetRasterBand(1).WriteRaster(0,0,1024,512,bytes([1,3])*262144); d=None",
        source_path.to_s
      )
      raise stderr unless status.success?

      data_import.options = {"raster_kind" => "categorical"}
      result = processor.call(source_path)
      output_path = work_dir.join(File.basename(result["output_key"]))
      values, stderr, status = Open3.capture3(
        "python3", "-c",
        "from osgeo import gdal; import sys,json; d=gdal.Open(sys.argv[1]); " \
        "print(json.dumps(sorted(set(d.GetRasterBand(1).GetOverview(0).ReadRaster()))))",
        output_path.to_s
      )
      raise stderr unless status.success?

      expect(JSON.parse(values) - [1, 3]).to be_empty
    end

    it "preserves an internal dataset mask" do
      create_raster("-ot", "Byte", "-burn", "123", "-a_srs", "EPSG:4326")
      _stdout, stderr, status = Open3.capture3(
        "python3", "-c",
        "from osgeo import gdal; import sys; gdal.SetConfigOption('GDAL_TIFF_INTERNAL_MASK', 'YES'); " \
        "d=gdal.Open(sys.argv[1], gdal.GA_Update); d.CreateMaskBand(gdal.GMF_PER_DATASET); " \
        "m=d.GetRasterBand(1).GetMaskBand(); m.Fill(255); m.WriteRaster(0,0,1,1,bytes([0])); d=None",
        source_path.to_s
      )
      raise stderr unless status.success?

      expect(processor.call(source_path)["bands"].first.dig("mask", "flags")).to eq(["PER_DATASET"])
    end
  end
end
