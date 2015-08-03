Rails.application.routes.draw do

  # Admin routes
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)

  # API routes
  mount Raddocs::App => "/docs"
  namespace :api, defaults: {format: 'json'} do
    scope module: :v1 do
      resources :layers, only: [:index]
    end
  end

  # Aplication
  root 'welcome#index'
  get 'map', to: 'map#index'
  get 'about', to: 'about#index'

end
