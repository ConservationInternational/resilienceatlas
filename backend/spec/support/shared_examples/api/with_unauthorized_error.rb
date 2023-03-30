require "swagger_helper"

RSpec.shared_examples "with unauthorized error" do
  response "401", "Unauthorized", generate_swagger_example: true do
    let(:Authorization) { "WRONG_API_TOKEN" }

    run_test!
  end
end
