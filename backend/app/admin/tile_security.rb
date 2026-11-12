require "csv"

ActiveAdmin.register_page "Tile Security" do
  menu parent: "Map Content", label: "Tile Security", priority: 3

  controller do
    helper_method :security_layers, :security_report, :filtered_security_layers, :security_counts, :security_verification

    def current_ability
      @current_ability ||= Ability.new(current_admin_user)
    end

    def security_layers
      layers = Layer.accessible_by(current_ability, :read).includes(:translations, :site_scopes).order(:id)
      if params[:site_scope_id].present?
        scope = SiteScope.accessible_by(current_ability, :read).find(params[:site_scope_id])
        layers = layers.joins(:layer_groups).where(layer_groups: {site_scope_id: scope.id}).distinct
      end
      layers
    end

    def security_report(layer)
      @security_reports ||= {}
      return @security_reports[layer.id] if @security_reports.key?(layer.id)
      @policy_reports ||= TileSecurityPolicy.reports_for(security_layers.to_a)
      report = @policy_reports.fetch(layer.id).deep_dup
      @pending_invalidations ||= TileCacheInvalidation.where(layer_id: security_layers.select(:id),
        status: %w[pending submitted failed]).distinct.pluck(:layer_id).to_set
      if @pending_invalidations.include?(layer.id)
        report["reasons"] |= ["cache_invalidation_pending"]
        report["status"] = "warning" if report["status"] == "ready"
      end
      @security_reports[layer.id] = report
    end

    def filtered_security_layers
      return security_layers if params[:status].blank? || params[:status] == "all"
      security_layers.select do |layer|
        report = security_report(layer)
        if security_problem_filters.key?(params[:status])
          report.fetch("reasons").include?(security_problem_filters.fetch(params[:status]))
        elsif params[:status] == "awaiting_review"
          @pending_reviews ||= TileSecurityReview.where(layer_id: security_layers.select(:id),
            status: "pending").distinct.pluck(:layer_id).to_set
          @pending_reviews.include?(layer.id)
        elsif params[:status] == "not_verified"
          security_verification(layer).fetch(:status) != "passed"
        else
          (params[:status] == "needs_attention") ? report["status"] != "ready" : report["status"] == params[:status]
        end
      end
    end

    def security_counts
      security_layers.each_with_object(Hash.new(0)) do |layer, counts|
        counts[security_report(layer).fetch("status")] += 1
      end
    end

    def security_verification(layer)
      @latest_verifications ||= TileSecurityVerification.where(layer_id: security_layers.select(:id))
        .select("DISTINCT ON (layer_id) layer_id, status, source_version, created_at")
        .order(:layer_id, created_at: :desc, id: :desc).index_by(&:layer_id)
      verification = @latest_verifications[layer.id]
      return {status: "not_verified", at: nil} unless verification

      status = (verification.source_version == security_report(layer).fetch("version")) ? verification.status : "stale"
      {status: status, at: verification.created_at}
    end

    def security_problem_filters
      {
        "public_uncached" => "cache_route_not_active",
        "source_changed" => "source_changed_review_required",
        "pending_invalidation" => "cache_invalidation_pending",
        "import_failed" => "import_security_reconciliation_failed",
        "exposure_warning" => "shared_source_public_alias"
      }
    end
  end

  page_action :export, method: :get do
    response.cache_control.replace(private: true, no_store: true)
    body = CSV.generate do |csv|
      csv << %w[id slug provider publication data_policy status reasons version verification verified_at config_diagnostics]
      filtered_security_layers.each do |layer|
        report = security_report(layer)
        verification = security_verification(layer)
        values = [layer.id, layer.slug, layer.layer_provider, layer.published, layer.data_policy,
          report["status"], report["reasons"].join(";"), report["version"], verification[:status], verification[:at]&.iso8601,
          report.fetch("config_diagnostics").map { |diagnostic| "#{diagnostic.fetch("code")}: #{diagnostic.fetch("message")}" }.join("; ")]
        csv << values.map { |value| (value.is_a?(String) && value.match?(/\A[=+@\-\t\r\n]/)) ? "'#{value}" : value }
      end
    end
    send_data body, filename: "tile-security.csv", type: "text/csv"
  end

  content title: "Tile security and cache readiness" do
    para "Configuration checks only unless a recent live verification is shown. Draft/protected restrictions are not necessarily errors."
    para security_counts.map { |status, count| "#{status.humanize}: #{count}" }.join(" | ")
    para link_to "Export authorized layers (CSV)", admin_tile_security_export_path(params.permit(:site_scope_id, :status).to_h)
    form action: admin_tile_security_path, method: :get do
      label "Site scope"
      select name: "site_scope_id" do
        option "All authorized scopes", value: ""
        SiteScope.accessible_by(current_ability, :read).with_translations.each do |scope|
          option scope.name, value: scope.id, selected: params[:site_scope_id].to_s == scope.id.to_s
        end
      end
      select name: "status" do
        %w[all needs_attention blocked warning unknown ready public_uncached source_changed pending_invalidation import_failed exposure_warning awaiting_review not_verified].each do |status|
          option status.humanize, value: status, selected: params[:status] == status
        end
      end
      input type: "submit", value: "Filter"
    end
    page_number = [params[:page].to_i, 1].max
    filtered = filtered_security_layers
    layers = filtered.is_a?(Array) ? filtered.slice((page_number - 1) * 50, 50).to_a : filtered.offset((page_number - 1) * 50).limit(50)
    table_for layers do
      column("Layer") { |layer| link_to layer.slug, admin_layer_path(layer) }
      column :layer_provider
      column :published
      column :data_policy
      column "Configuration" do |layer|
        report = security_report(layer)
        status_tag report["status"]
        div report["reasons"].join(", ")
        report.fetch("config_diagnostics").each do |diagnostic|
          div "#{diagnostic.fetch("code")}: #{diagnostic.fetch("message")}"
        end
      end
      column("Generation") { |layer| layer.tile_cache_version }
      column("Live verification") do |layer|
        verification = security_verification(layer)
        div verification[:status].humanize
        div verification[:at]
      end
    end
    para link_to("Previous", admin_tile_security_path(params.permit(:site_scope_id, :status).to_h.merge(page: page_number - 1))) if page_number > 1
    para link_to("Next", admin_tile_security_path(params.permit(:site_scope_id, :status).to_h.merge(page: page_number + 1))) if layers.size == 50
    if current_admin_user.superadmin?
      panel "Unreferenced vector sources (first 1000 relations)" do
        para "Informational inventory only; never auto-published."
        para TileSourceInventory.orphans(current_admin_user).join(", ")
      end
      panel "Deployment configuration (presence only, not a live check)" do
        %w[TILE_CACHE_REDIS_URL TILE_PUBLIC_CDN_URL TILE_CLOUDFRONT_DISTRIBUTION_IDS DATA_GATEWAY_SECRET].each do |name|
          para "#{name}: #{ENV[name].present? ? "configured" : "not configured"}"
        end
      end
    end
  end
end
