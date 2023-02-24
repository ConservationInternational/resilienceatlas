require 'acceptance_helper'

resource 'Layer' do
  header "Accept", "application/json; application/vnd.api+json"
  header "Content-Type", "application/vnd.api+json"
  header 'Host', 'http://resilienceatlas.org'
  header 'X-CSRF-Token', 'a_valid_CSRF_token'

  let!(:layer_group) do
    LayerGroup.create!(name: 'environment', id: 1, site_scope: SiteScope.create!(name: 'CIGRP', id: 1, header_theme: 'vs-theme'))
  end

  let!(:layers) do
    layers = []
    3.times do |i|
      layers << create(:layer, name: "test layer #{i}", slug: "test-layer-#{i}", download: false, id: i)
    end
    layers.each(&:reload)
  end

  let!(:agrupation) do
    3.times do |i|
      Agrupation.create!(layer_group_id: 1, layer_id: i)
    end
  end

  context "List layers" do
    get "/api/layers" do
      parameter :site_scope, 'Site scope to list layers for'

      example_request "Get layers list" do
        expect(status).to eq(200)
        results = json
        expect(results.length).to eq(3)
        names = results.map{ |r| r['attributes']['name'] }
        expect names.include?(['test layer 0', 'test layer 1', 'test layer 2'])
      end
    end
  end

  context "Download layer files" do
    before :each do
      sign_in_as_a_user
    end

    get '/api/layers/:id/downloads' do
      parameter :download_path, 'Url to the file download'
      parameter :file_format, 'File format (pdf, kml, jpg, txt, etc..)'
      parameter :with_format, 'If format is part of download_path'

      let!(:layer) do
        layers[0].update(download: true, sources: [FactoryBot.create(:source_layer)])
        layer = layers[0]
      end

      let(:stub_layer_zip) { "#{Rails.root}/downloads/#{layer.name.parameterize}-date-#{DateTime.now.to_date.to_s.parameterize}-main.zip" }

      example 'Download the layer pdf of a specific layer without layer file' do
        do_request(id: layer.id)
        allow_any_instance_of(Layer).to receive(:zipfile_name).and_return(stub_layer_zip)

        expect(status).to                       eq(200)
        expect(File.exists?(stub_layer_zip)).to eq(true)

        Zip::File.open(stub_layer_zip) do |zip_file|
          expect(zip_file.first.name).to eq(File.basename('test-layer-0.pdf'))
        end
        File.delete(stub_layer_zip)
      end

      example 'Download the layer pdf of a specific layer with layer file kml' do
        do_request(id: layer.id,
                   file_format: 'kml',
                   with_format: true,
                   download_path: 'https://cdb-cdn.resilienceatlas.org/user/ra/api/v2/sql?filename=africa_infant_mortality_rate&q=with r as (select the_geom,the_geom_webmercator, dhsregen,iso3,reg_id,svytype,svyyear from grp_dhs_regions)
                                   SELECT distinct on (l.regionid, l.surveyyear) l.regionid, l.surveyyear, l.indicatorid, l.byvariableid, characteristiclabel, l.value,  r.the_geom_webmercator, r.the_geom FROM dhs_export l inner join r on regionid=reg_id where indicatorid = 70254002&format=kml')

        allow_any_instance_of(Layer).to receive(:zipfile_name).and_return(stub_layer_zip)

        expect(status).to                       eq(200)
        expect(File.exists?(stub_layer_zip)).to eq(true)

        Zip::File.open(stub_layer_zip) do |zip_file|
          expect(zip_file.first.name).to eq(File.basename('africa_infant_mortality_rate&q.kml'))
        end
        File.delete(stub_layer_zip)
      end

      example 'Download the layer pdf of a specific layer with external file' do
        do_request(id: layer.id,
                   file_format: 'pdf',
                   download_path: 'http://www.hgd1952.hr/pdf_datoteke/Test_document_PDF.pdf')

        allow_any_instance_of(Layer).to receive(:zipfile_name).and_return(stub_layer_zip)

        expect(status).to                       eq(200)
        expect(File.exists?(stub_layer_zip)).to eq(true)

        Zip::File.open(stub_layer_zip) do |zip_file|
          expect(zip_file.first.name).to eq(File.basename('test-layer-0-extra.pdf'))
        end
        File.delete(stub_layer_zip)
      end

      context 'For zip file date expired' do
        before :each do
          FileUtils.touch("#{Rails.root}/downloads/#{layer.name.parameterize}-date-2014-06-09-main.zip")
        end

        let(:stub_layer_expired_zip) { "#{Rails.root}/downloads/#{layer.name.parameterize}-date-2014-06-09-main.zip" }

        example 'Download the layer pdf of a specific layer without layer file and date expiration' do
          do_request(id: layer.id)
          allow_any_instance_of(Layer).to receive(:zipfile_name).and_return(stub_layer_zip)

          expect(status).to                                    eq(200)
          expect(File.exists?(stub_layer_zip)).to              eq(true)
          expect(File.exists?(stub_layer_expired_zip.to_s)).to eq(true)

          Zip::File.open(stub_layer_zip) do |zip_file|
            expect(zip_file.first.name).to eq(File.basename('test-layer-0.pdf'))
          end
          File.delete(stub_layer_zip)
          File.delete(stub_layer_expired_zip.to_s)
        end
      end

      example 'Do not allow to download files if layer download false', document: false do
        do_request(id: layers[2].id)
        allow_any_instance_of(Layer).to receive(:zipfile_name).and_return(stub_layer_zip)

        expect(status).to                       eq(200)
        expect(File.exists?(stub_layer_zip)).to eq(false)
        expect(json_main['message']).to         eq('No files for specified layer')
      end

      context 'Creating pdf without sources' do
        let!(:layer) do
          layers[0].update(download: true, sources: [])
          layer = layers[0]
        end

        let(:stub_layer_zip) { "#{Rails.root}/downloads/#{layer.name.parameterize}-date-#{DateTime.now.to_date.to_s.parameterize}-main.zip" }

        example 'Download the layer pdf of a specific layer without layer file and sources' do
          do_request(id: layer.id)
          allow_any_instance_of(Layer).to receive(:zipfile_name).and_return(stub_layer_zip)

          expect(status).to                       eq(200)
          expect(File.exists?(stub_layer_zip)).to eq(true)

          Zip::File.open(stub_layer_zip) do |zip_file|
            expect(zip_file.first.name).to eq(File.basename('test-layer-0.pdf'))
          end
          File.delete(stub_layer_zip)
        end
      end
    end
  end
end
