require "swagger_helper"

RSpec.describe "API V1 Layer", type: :request do
  path "/api/layers" do
    get "Get list of layers" do
      tags "Layer"
      consumes "application/json"
      produces "application/json"
      parameter name: :site_scope, in: :query, type: :string, description: "Site scope to list layers for", required: false
      parameter name: :locale, in: :query, type: :string, description: "Used language. Default: en", required: false

      let(:default_site_scope) { create :site_scope, id: 1, name: "CIGRP" }
      let(:layer_group) { create :layer_group, site_scope: default_site_scope }
      let!(:layers) { create_list :layer, 3, download: false, layer_groups: [layer_group] }
      let(:site_scope) { default_site_scope.subdomain }

      response "200", :success do
        run_test!

        it "matches snapshot", generate_swagger_example: true do
          expect(response.body).to match_snapshot("api/v1/layers")
        end
      end
    end
  end

  path "/api/layers/{id}/downloads" do
    get "Download layer file" do
      tags "Layer"
      consumes "application/json"
      produces "application/zip"
      parameter name: :id, in: :path, type: :integer, description: "Layer ID"
      parameter name: :download_path, in: :query, type: :string, description: "Url to the file download", required: false
      parameter name: :file_format, in: :query, type: :string, description: "File format (pdf, kml, jpg, txt, etc..)", required: false
      parameter name: :with_format, in: :query, type: :string, description: "If format is part of download_path", required: false

      let(:default_site_scope) { create :site_scope, id: 1, name: "CIGRP" }
      let(:layer_group) { create :layer_group, site_scope: default_site_scope }
      let(:layer) { create :layer, download: true, layer_groups: [layer_group] }
      let(:stub_layer_zip) { "#{Rails.root}/downloads/#{layer.name.parameterize}-date-#{DateTime.now.to_date.to_s.parameterize}-main.zip" }
      let(:id) { layer.id }

      response "200", :success do
        context "when downloading the layer pdf of a specific layer without layer file" do
          before { allow_any_instance_of(Layer).to receive(:zipfile_name).and_return(stub_layer_zip) }
          after { File.delete(stub_layer_zip) }

          run_test!

          it "downloads file" do
            expect(File.exist?(stub_layer_zip)).to be_truthy
            Zip::File.open(stub_layer_zip) do |zip_file|
              expect(zip_file.first.name).to eq(File.basename("#{layer.name.parameterize}.pdf"))
            end
          end
        end

        context "when downloading the layer pdf of a specific layer with layer file kml" do
          let(:file_format) { "kml" }
          let(:with_format) { true }
          let(:download_path) do
            'https://cdb-cdn.resilienceatlas.org/user/ra/api/v2/sql?filename=africa_infant_mortality_rate&q=with r as (select the_geom,the_geom_webmercator, dhsregen,iso3,reg_id,svytype,svyyear from grp_dhs_regions)
             SELECT distinct on (l.regionid, l.surveyyear) l.regionid, l.surveyyear, l.indicatorid, l.byvariableid, characteristiclabel, l.value,  r.the_geom_webmercator, r.the_geom FROM dhs_export l inner join r on regionid=reg_id where indicatorid = 70254002&format=kml'
          end

          before do
            allow_any_instance_of(Layer).to receive(:zipfile_name).and_return(stub_layer_zip)
            stub_request(:get, "https://cdb-cdn.resilienceatlas.org/user/ra/api/v2/sql?filename=africa_infant_mortality_rate&format=kml&q=with%20r%20as%20(select%20the_geom,the_geom_webmercator,%20dhsregen,iso3,reg_id,svytype,svyyear%20from%20grp_dhs_regions)%20%20%20%20%20%20%20%20%20%20%20%20%20SELECT%20distinct%20on%20(l.regionid,%20l.surveyyear)%20l.regionid,%20l.surveyyear,%20l.indicatorid,%20l.byvariableid,%20characteristiclabel,%20l.value,%20%20r.the_geom_webmercator,%20r.the_geom%20FROM%20dhs_export%20l%20inner%20join%20r%20on%20regionid=reg_id%20where%20indicatorid%20=%2070254002")
              .to_return(status: 200, body: File.new(Rails.root.join("spec/fixtures/files/carto_data.kml")), headers: {})
          end
          after { File.delete(stub_layer_zip) }

          run_test!

          it "downloads file" do
            expect(File.exist?(stub_layer_zip)).to be_truthy
            Zip::File.open(stub_layer_zip) do |zip_file|
              expect(zip_file.first.name).to eq(File.basename("africa_infant_mortality_rate.kml"))
            end
          end
        end

        context "when downloading the layer pdf of a specific layer with external file" do
          let(:file_format) { "pdf" }
          let(:download_path) { "http://www.hgd1952.hr/pdf_datoteke/Test_document_PDF.pdf" }

          before do
            allow_any_instance_of(Layer).to receive(:zipfile_name).and_return(stub_layer_zip)
            stub_request(:get, "http://www.hgd1952.hr/pdf_datoteke/Test_document_PDF.pdf")
              .to_return(status: 200, body: File.new(Rails.root.join("spec/fixtures/files/document.pdf")), headers: {})
          end
          after { File.delete(stub_layer_zip) }

          run_test!

          it "downloads file" do
            expect(File.exist?(stub_layer_zip)).to be_truthy
            Zip::File.open(stub_layer_zip) do |zip_file|
              expect(zip_file.first.name).to eq(File.basename("#{layer.name.parameterize}-extra.pdf"))
            end
          end
        end

        context "when zip file date expired" do
          let(:stub_layer_expired_zip) { "#{Rails.root}/downloads/#{layer.name.parameterize}-date-2014-06-09-main.zip" }

          before do
            FileUtils.touch(stub_layer_expired_zip)
            allow_any_instance_of(Layer).to receive(:zipfile_name).and_return(stub_layer_zip)
          end
          after do
            File.delete(stub_layer_zip)
            File.delete(stub_layer_expired_zip)
          end

          run_test!

          it "downloads file" do
            expect(File.exist?(stub_layer_zip)).to be_truthy
            expect(File.exist?(stub_layer_expired_zip)).to be_truthy
            Zip::File.open(stub_layer_zip) do |zip_file|
              expect(zip_file.first.name).to eq(File.basename("#{layer.name.parameterize}.pdf"))
            end
          end
        end

        context "when layer download is false" do
          let(:layer) { create :layer, download: false, layer_groups: [layer_group] }

          run_test!

          it "does not allow to download file" do
            expect(File.exist?(stub_layer_zip)).to be_falsey
            expect(response_json["message"]).to eq("No files for specified layer")
          end
        end

        context "when creating pdf without sources" do
          let(:layer) { create :layer, download: true, layer_groups: [layer_group], sources: [] }

          before { allow_any_instance_of(Layer).to receive(:zipfile_name).and_return(stub_layer_zip) }
          after { File.delete(stub_layer_zip) }

          run_test!

          it "downloads file" do
            expect(File.exist?(stub_layer_zip)).to be_truthy
            Zip::File.open(stub_layer_zip) do |zip_file|
              expect(zip_file.first.name).to eq(File.basename("#{layer.name.parameterize}.pdf"))
            end
          end
        end
      end
    end
  end
end
