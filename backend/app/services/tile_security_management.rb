class TileSecurityManagement
  def initialize(actor)
    @actor = actor
    @ability = Ability.new(actor)
  end

  def set_policy!(layer, policy:, reason:)
    @ability.authorize! :update, layer
    raise CanCan::AccessDenied unless @actor.superadmin?
    raise ArgumentError, "A review reason is required" if reason.blank?
    raise ArgumentError, "Invalid data policy" unless %w[public restricted].include?(policy)

    layer.with_lock do
      before = layer.data_policy
      layer.update!(data_policy: policy, public_data: policy == "public", security_provenance: "explicit")
      TileSecurityEvent.create!(layer: layer, admin_user: @actor, action: "set_policy", reason: reason,
        details: {before: before, after: policy, version: layer.tile_cache_version})
    end

    layer
  end

  def publish!(layer)
    @ability.authorize! :update, layer
    layer.with_lock do
      report = TileSecurityPolicy.new(layer).report
      blockers = report.fetch("reasons") & %w[invalid_provider_config source_missing_or_unresolved no_scope_assignment import_security_reconciliation_failed]
      raise ArgumentError, "Cannot publish: #{blockers.join(", ")}" if blockers.any?
      layer.update!(published: true)
      TileSecurityEvent.create!(layer: layer, admin_user: @actor,
        action: "publish", reason: "Published by authorized administrator", details: {version: layer.tile_cache_version})
    end
  end

  def request_review!(layer, reason:)
    @ability.authorize! :update, layer
    TileSecurityReview.create!(layer: layer, admin_user: @actor, reason: reason,
      source_version: TileSecurityPolicy.new(layer).version)
  end

  def resolve_review!(review, approve:, reason:)
    raise CanCan::AccessDenied unless @actor.superadmin?
    raise ArgumentError, "A resolution reason is required" if reason.blank?
    review.layer.with_lock do
      review.with_lock do
        raise ArgumentError, "Review is no longer pending" unless review.status == "pending"
        if review.source_version != TileSecurityPolicy.new(review.layer).version
          review.update!(status: "stale", resolution: "Source or policy changed; submit a new review")
        else
          set_policy!(review.layer, policy: "public", reason: reason) if approve
          review.update!(status: approve ? "approved" : "rejected", resolution: reason)
          TileSecurityEvent.create!(layer: review.layer, admin_user: @actor, action: "resolve_review",
            reason: reason, details: {review_id: review.id, approved: approve})
        end
      end
    end
    review
  end
end
