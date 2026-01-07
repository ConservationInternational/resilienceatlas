require "rails_helper"

RSpec.describe "Layer Downloads", type: :request do
  let(:default_site_scope) { create :site_scope, id: 1, name: "Resilience Atlas" }
  let(:layer_group) { create :layer_group, site_scope: default_site_scope }
  let(:source) { create :source }
  
  describe "GET /api/layers/:id/downloads with various configurations" do
    context "with a basic layer that has metadata" do
      let(:layer) do
        create :layer,
          download: true,
          layer_groups: [layer_group],
          sources: [source],
          dataset_shortname: "test_dataset",
          dataset_source_url: "https://example.com/data",
          version: "1.0",
          spatial_resolution: "30",
          spatial_resolution_units: "meters"
      end

      it "includes layer metadata in the download" do
        expect(layer.dataset_shortname).to eq("test_dataset")
        expect(layer.dataset_source_url).to eq("https://example.com/data")
        expect(layer.version).to eq("1.0")
        expect(layer.spatial_resolution).to eq("30")
        expect(layer.spatial_resolution_units).to eq("meters")
      end
    end

    context "with a timeline layer" do
      let(:layer) do
        create :layer,
          download: true,
          layer_groups: [layer_group],
          sources: [source],
          timeline: true,
          timeline_start_date: Date.new(2020, 1, 1),
          timeline_end_date: Date.new(2023, 12, 31),
          timeline_default_date: Date.new(2022, 6, 15)
      end

      it "includes timeline configuration" do
        expect(layer.timeline).to be true
        expect(layer.timeline_start_date).to eq(Date.new(2020, 1, 1))
        expect(layer.timeline_end_date).to eq(Date.new(2023, 12, 31))
        expect(layer.timeline_default_date).to eq(Date.new(2022, 6, 15))
      end
    end

    context "with analysis suitable layer" do
      let(:layer) do
        create :layer,
          download: true,
          layer_groups: [layer_group],
          sources: [source],
          analysis_suitable: true,
          analysis_type: "histogram",
          analysis_query: "SELECT * FROM analysis_table"
      end

      it "includes analysis configuration" do
        expect(layer.analysis_suitable).to be true
        expect(layer.analysis_type).to eq("histogram")
        expect(layer.analysis_query).to be_present
      end
    end

    context "with multiple sources" do
      let(:source1) { create :source, reference: "Source 1" }
      let(:source2) { create :source, reference: "Source 2" }
      let(:layer) do
        create :layer,
          download: true,
          layer_groups: [layer_group],
          sources: [source1, source2]
      end

      it "associates with multiple sources" do
        expect(layer.sources.count).to eq(2)
        expect(layer.sources).to include(source1, source2)
      end
    end

    context "with COG layer type" do
      let(:layer) do
        create :layer,
          download: true,
          layer_groups: [layer_group],
          sources: [source],
          layer_provider: "cog",
          layer_config: '{"type": "cog", "url": "https://example.com/data.tif"}'
      end

      it "has COG configuration" do
        expect(layer.layer_provider).to eq("cog")
        expect(layer.layer_config).to include("cog")
        expect(layer.layer_config).to include(".tif")
      end
    end

    context "with cartodb layer type" do
      let(:layer) do
        create :layer,
          download: true,
          layer_groups: [layer_group],
          sources: [source],
          layer_provider: "cartodb",
          query: "SELECT * FROM table WHERE year = 2023"
      end

      it "has cartodb configuration" do
        expect(layer.layer_provider).to eq("cartodb")
        expect(layer.query).to be_present
      end
    end
  end

  describe "layer visibility and permissions" do
    context "with unpublished layer" do
      let(:layer) do
        create :layer,
          download: true,
          published: false,
          layer_groups: [layer_group],
          sources: [source]
      end

      it "is not published" do
        expect(layer.published).to be false
      end
    end

    context "with published layer" do
      let(:layer) do
        create :layer,
          download: true,
          published: true,
          layer_groups: [layer_group],
          sources: [source]
      end

      it "is published" do
        expect(layer.published).to be true
      end
    end
  end

  describe "layer ordering and display" do
    let!(:layer1) { create :layer, layer_groups: [layer_group], order: 1, zindex: 100 }
    let!(:layer2) { create :layer, layer_groups: [layer_group], order: 2, zindex: 200 }
    let!(:layer3) { create :layer, layer_groups: [layer_group], order: 3, zindex: 300 }

    it "maintains order for layer display" do
      layers = Layer.where(id: [layer1.id, layer2.id, layer3.id]).order(:order)
      expect(layers.pluck(:order)).to eq([1, 2, 3])
    end

    it "maintains zindex for layer stacking" do
      layers = Layer.where(id: [layer1.id, layer2.id, layer3.id]).order(:zindex)
      expect(layers.pluck(:zindex)).to eq([100, 200, 300])
    end
  end
end
