class JsonValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return unless value.present?

    value = parse_json value
    validate_json_schema_of record, attribute, value
  rescue JSON::Schema::ValidationError => e
    message = options[:message] || e.message
    record.errors.add(attribute, :json, message: message, value: value)
  rescue JSON::ParserError => _e
    message = options[:message] || "must be a valid JSON"
    record.errors.add(attribute, :json, message: message, value: value)
  end

  private

  def parse_json(value)
    return JSON.parse value if value.is_a? String

    value
  end

  def validate_json_schema_of(record, attribute, value)
    schema_name = options[:schema] || attribute
    schema = Rails.root.join("app/models/json_schemas/#{record.class.to_s.underscore}/#{schema_name}.json")
    JSON::Validator.validate!(schema.to_s, value)
  end
end
