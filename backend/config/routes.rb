Rails.application.routes.draw do
  # Health check endpoints at root level
  get "health", to: "api/health#show"
  get "health/ready", to: "api/health#ready"

  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"

  # Sidekiq Web UI — constrained to authenticated AdminUsers
  require "sidekiq/web"
  authenticate :admin_user do
    mount Sidekiq::Web => "/admin/sidekiq"
  end

  # Users
  get "/users/:id/profile/edit", to: "api/v1/users#edit", as: :edit_user
  patch "/users/:id/profile/update", to: "api/v1/users#update", as: :update_user
  get "users/me", to: "api/v1/users#edit"
  patch "users/me", to: "api/v1/users#update"

  post "users/register", to: "api/v1/registrations#create"
  post "users/authenticate", to: "api/v1/authentications#authenticate"

  # SHORTCUTS USING API
  get "services/oembed", to: "api/v1/oembeds#show"

  # API routes
  namespace :api, defaults: {format: "json"} do
    # Health check endpoints
    get "health", to: "health#show"
    get "health/ready", to: "health#ready"

    namespace :admin do
      resources :layers do
        collection do
          get :site_scopes
        end
      end
    end
    scope module: :v1 do
      get "layer-groups", to: "layer_groups#index", as: "layer_groups"
      get "/layers", to: "layers#index", as: "layers"
      get "/layers/:id/downloads", to: "layers#download_attachments", as: "download_attachments"

      # S3 multipart upload coordination (used by Uppy in ActiveAdmin)
      scope "uploads/multipart" do
        post "/", to: "uploads#create_multipart"
        get "/:upload_id", to: "uploads#sign_parts"
        get "/:upload_id/batch", to: "uploads#batch_sign_parts"
        post "/:upload_id/complete", to: "uploads#complete_multipart"
        delete "/:upload_id", to: "uploads#abort_multipart"
      end
      get "/share/:uid", to: "share_urls#show"
      post "/share", to: "share_urls#create"
      get "/sites", to: "sites#index"
      get "/site", to: "sites#show"
      get "/models", to: "models#index"
      get "/indicators", to: "indicators#index"
      get "/categories", to: "categories#index"
      get "/journeys", to: "journeys#index"
      get "/journeys/:id", to: "journeys#show"
      get "/menu-entries", to: "menu_entries#index"
      get "/homepage", to: "homepages#show"

      # Admin boundaries (country/province/district polygons)
      get "/admin-boundaries", to: "admin_boundaries#index"
      get "/admin-boundaries/:iso_code", to: "admin_boundaries#show"

      # Scope datasets (pre-computed statistics for site scopes)
      get "/scope-datasets", to: "scope_datasets#index"
      get "/scope-datasets/intersecting-units", to: "scope_datasets#intersecting_units"
      get "/scope-datasets/geometry-at-point", to: "scope_datasets#geometry_at_point"
      get "/scope-datasets/ldn-ecoregion-at-point", to: "scope_datasets#ldn_ecoregion_at_point"
      get "/scope-datasets/:slug/geometry-bounds/:unit_id", to: "scope_datasets#geometry_bounds"
      get "/scope-datasets/:slug", to: "scope_datasets#show"

      # Site scope authentication endpoints
      post "/site-scope/authenticate", to: "site_scope_authentications#authenticate"
      get "/site-scope/check-access", to: "site_scope_authentications#check_access"

      # TiTiler proxy endpoints for COG operations (avoids CORS issues)
      get "/titiler/info", to: "titiler#info"
      post "/titiler/statistics", to: "titiler#statistics"
      get "/titiler/point", to: "titiler#point"

      resources :photos, only: :create
      resources :feedbacks, only: :create
      resources :static_pages, only: :show
    end
  end

  # Admin routes
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
end
