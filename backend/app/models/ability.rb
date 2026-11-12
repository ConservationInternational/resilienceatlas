class Ability
  include CanCan::Ability

  def initialize(admin_user)
    @admin_user = admin_user

    return unless @admin_user
    if @admin_user.superadmin?
      can :manage, :all
      return
    end

    allowed_ids = @admin_user.allowed_site_scope_ids
    can :read, ActiveAdmin::Page, name: "Dashboard"
    can :read, ActiveAdmin::Page, name: "Tile Security"
    can [:export, :verify], ActiveAdmin::Page, name: "Tile Security"
    can [:read, :update], AdminUser, id: @admin_user.id
    can :read, SiteScope, id: allowed_ids
    can :read, LayerGroup, site_scope_id: allowed_ids
    can :read, Layer, id: authorized_layer_ids(allowed_ids)
    can [:refresh_preview, :verify_security], Layer, id: authorized_layer_ids(allowed_ids)
    if @admin_user.admin?
      can :update, SiteScope, id: allowed_ids
      can :manage, Layer, id: authorized_layer_ids(allowed_ids)
      can :create, Layer
      can :manage, LayerGroup, site_scope_id: allowed_ids
      can :manage, ScopeDataset, site_scope_id: allowed_ids
      can :manage, SitePage, site_scope_id: allowed_ids
      can :manage, Homepage, site_scope_id: allowed_ids
      can :manage, DataImport, admin_user_id: @admin_user.id
    elsif @admin_user.contributor?
      can :create, Layer
      can :manage, DataImport, admin_user_id: @admin_user.id
    end
  end

  def authorize_upload!(upload, read_only: false, options: upload.options)
    raise CanCan::AccessDenied unless @admin_user && upload.admin_user_id == @admin_user.id
    authorize! :manage, upload
    return if @admin_user.superadmin?

    if upload.importable
      authorize!(read_only ? :read : :update, upload.importable)
    else
      scope_id = options["site_scope_id"].to_i
      raise CanCan::AccessDenied unless options["mode"] == "create" && @admin_user.allowed_site_scope_ids.include?(scope_id)
    end
  end

  private

  def authorized_layer_ids(allowed_ids)
    # Shared records must not expose or modify data belonging to other scopes.
    assigned = Layer.joins(:layer_groups).where(layer_groups: {site_scope_id: allowed_ids}).select(:id)
    forbidden = Layer.joins(:layer_groups).where.not(layer_groups: {site_scope_id: allowed_ids}).select(:id)
    Layer.where(id: assigned).where.not(id: forbidden).pluck(:id)
  end
end
