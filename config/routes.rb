Rails.application.routes.draw do

  # Admin routes
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)

  # API routes
  mount Raddocs::App => "/docs"
  namespace :api, defaults: {format: 'te'} do
    scope module: :v1 do
      resources 'layer-groups', controller: :layer_groups, as: :layer_groups, only: [:index]
      resources :layers, only: [:index]
      get '/share/:uid', to: 'share_urls#show'
      post '/share', to: 'share_urls#create'
    end
  end

  # Application
  get '/', to: 'map#index', constraints: { subdomain: /indicators.+/ }
  get '/', to: 'welcome#index', as: 'root'

  get 'map', to: 'map#index'
  get 'about', to: 'about#index'

  resources :journeys, only: [:show]

  # Embed
  get 'embed', to: 'embed#index'
  get 'embed/map', to: 'embed#map'
  get 'embed/journeys', to: 'embed#journeys'
  get 'embed/test', to: 'embed#test'

end
