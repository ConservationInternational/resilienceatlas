class AdminPreviewAccess
  def self.issue(record, actor)
    ability = Ability.new(actor)
    record.is_a?(Layer) ? ability.authorize!(:read, record) : ability.authorize_upload!(record, read_only: true)
    JWT.encode({purpose: "data_preview", type: record.class.name, id: record.id,
                actor: actor.id, exp: 5.minutes.from_now.to_i}, Rails.application.secret_key_base, "HS256")
  end

  def self.resolve(token, type)
    return if token.blank?

    payload = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: "HS256").first
    return unless payload["purpose"] == "data_preview" && payload["type"] == type.name && payload["exp"].is_a?(Numeric)

    actor = AdminUser.find_by(id: payload["actor"])
    record = type.find_by(id: payload["id"])
    return unless actor && record

    ability = Ability.new(actor)
    record.is_a?(Layer) ? ability.authorize!(:read, record) : ability.authorize_upload!(record, read_only: true)

    record
  rescue JWT::DecodeError, CanCan::AccessDenied
    Rails.logger.warn "[AdminPreviewAccess] Rejected invalid or unauthorized preview token"
    nil
  end
end
