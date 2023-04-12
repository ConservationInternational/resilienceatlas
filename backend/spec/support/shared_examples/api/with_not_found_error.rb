require "swagger_helper"

RSpec.shared_examples "with not found error" do
  response "404", "Not Found", generate_swagger_example: true do
    let(:id) { "not-found" }
    let(:uid) { "not-found" }
    let(:slug) { "not-found" }

    run_test!
  end
end
