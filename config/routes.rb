Rails.application.routes.draw do
  # Users
  devise_for :users, path: 'users', path_names: { sign_in: 'login', sign_out: 'logout', password: 'secret',
                                                 confirmation: 'verification', unlock: 'unblock',
                                                 registration: 'register', sign_up: 'signup' },
                                                 controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }

  get   '/users/:id/finish_signup', to: 'users/user_account#finish_signup', as: :finish_signup
  patch '/users/:id/finish_signup', to: 'users/user_account#finish_signup', as: :update_signup

  get   '/users/:id/profile/edit',   to: 'users/user_account#edit',   as: :edit_user
  patch '/users/:id/profile/update', to: 'users/user_account#update', as: :update_user

  # Admin routes
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)

  # API routes
  mount Raddocs::App => '/docs'
  namespace :api, defaults: {format: 'te'} do
    scope module: :v1 do
      resources 'layer-groups', controller: :layer_groups, as: :layer_groups, only: [:index]
      resources :layers, only: [:index]
      get '/share/:uid', to: 'share_urls#show'
      post '/share', to: 'share_urls#create'
    end
  end

  # Application
  # get '/', to: 'map#index', constraints: { subdomain: /indicators.+/ }
  get '/', to: 'welcome#index', as: 'root'
  get '/wef', to: 'welcome#index', as: 'wef'

  # root 'welcome#index'

  get 'map', to: 'map#index', as: :map
  get 'about', to: 'about#index'
  get 'journeys', to: 'journeys#index'


  resources :journeys, only: [:show]

  # Embed
  get 'embed', to: 'embed#index'
  get 'embed/map', to: 'embed#map'
  get 'embed/journeys', to: 'embed#journeys'
  get 'embed/test', to: 'embed#test'

end
