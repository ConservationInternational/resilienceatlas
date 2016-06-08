require 'rails_helper'
require 'rspec_api_documentation/dsl'
require 'support/factory_girl'

RspecApiDocumentation.configure do |config|
  config.format    = [:json, :combined_text, :html]
  config.curl_host = 'http://resilienceatlas.org/api'
  config.api_name  = "Resilience Atlas API"
end
