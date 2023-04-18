Rails.application.routes.draw do
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"

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
      resources :photos, only: :create
      resources :feedbacks, only: :create
      resources :static_pages, only: :show
    end
  end

  # Admin routes
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
end
