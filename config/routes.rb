Rails.application.routes.draw do
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"

  namespace :api do
    mount_devise_token_auth_for "AdminUser", at: "auth"
    namespace :admin do
      resources :layers do
        collection do
          get :site_scopes
        end
      end
    end
  end
  # Users
  devise_for :users, path: "users", path_names: {sign_in: "login", sign_out: "logout", password: "secret",
                                                 confirmation: "verification", unlock: "unblock",
                                                 registration: "register", sign_up: "signup"},
    controllers: {omniauth_callbacks: "users/omniauth_callbacks",
                  sessions: "sessions", registrations: "registrations"}

  get "/users/:id/finish_signup", to: "users/user_account#finish_signup", as: :finish_signup
  patch "/users/:id/finish_signup", to: "users/user_account#finish_signup", as: :update_signup
  get "/users/:id/profile/edit", to: "users/user_account#edit", as: :edit_user
  patch "/users/:id/profile/update", to: "users/user_account#update", as: :update_user

  post "users/authenticate", to: "authentication#authenticate"
  get "users/me", to: "users/user_account#edit"
  patch "users/me", to: "users/user_account#update"

  # API routes
  namespace :api, defaults: {format: "json"} do
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
    end
  end

  get "services/oembed", to: "api/v1/oembeds#show"

  # Application
  # get '/', to: 'map#index', constraints: { subdomain: /indicators.+/ }
  # get '/', to: 'welcome#index', as: 'root'
  get "/wef", to: "welcome#index", as: "wef"

  get "map", to: "map#index", as: :map
  get "about", to: "about#index"
  get "journeys", to: "journeys#index"
  get "contents/:slug", to: "contents#show"
  get "report", to: "report#index", as: :report

  resources :journeys, only: [:show]

  # Embed
  get "embed", to: "embed#index"
  get "embed/map", to: "embed#map"
  get "embed/journeys", to: "embed#journeys"
  get "embed/test", to: "embed#test"

  # Admin routes
  mount Ckeditor::Engine => "/ckeditor"
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)

  # Root path
  root to: "welcome#index"
  resources :photos, only: :create
end
