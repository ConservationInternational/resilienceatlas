require "rails_helper"

RSpec.configure do |config|
  config.swagger_root = Rails.root.join("swagger").to_s

  config.after :each, generate_swagger_example: true do |example|
    example.metadata[:response][:content] = {
      "application/json" => {example: JSON.parse(response.body, symbolize_names: true)}
    }
  end

  config.swagger_docs = {
    "v1/swagger.yaml" => {
      openapi: "3.0.1",
      info: {
        title: "API V1",
        version: "v1"
      },
      paths: {},
      components: {
        securitySchemes: {
          cookie_auth: {
            type: :apiKey,
            name: "_backend_session",
            in: :cookie
          },
          tokenAuth: {
            type: :http,
            scheme: :bearer,
            name: "Authorization"
          },
          bearerAuth: {
            type: :http,
            scheme: :bearer,
            bearerFormat: :JWT,
            name: "Authorization"
          }
        },
        schemas: {
          errors: {
            type: :object,
            properties: {
              errors: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    status: {type: :string},
                    title: {type: :string}
                  },
                  required: %w[status title]
                }
              }
            },
            required: %w[errors]
          }
        }
      },
      servers: [
        {
          url: ""
        },
        {
          url: "{scheme}://{host}",
          variables: {
            scheme: {
              default: "http"
            },
            host: {
              default: "localhost:3000"
            }
          }
        }
      ]
    }
  }

  config.swagger_format = :yaml
end
