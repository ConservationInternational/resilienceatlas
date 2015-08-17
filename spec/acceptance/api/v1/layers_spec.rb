require 'acceptance_helper'

resource 'Layers' do
  header "Accept", "application/json; application/vnd.api+json"
  header "Content-Type", "application/vnd.api+json"
  header 'Host', 'http://cigrp.org'

  let!(:layer) do
    3.times do |i|
      FactoryGirl.create(:layer, name: "test layer #{i}")
    end
  end

  get "/api/layers/" do

    example_request "Get layers list" do
      expect(status).to eq(200)
      results = JSON.parse(response_body)['data']
      expect(results.length).to be == 3
      names = results.map{ |r| r['attributes']['name'] }
      expect names.include?(['test layer 0', 'test layer 1', 'test layer 2'])
    end
  end
end
