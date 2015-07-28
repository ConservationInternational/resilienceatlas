Rails.application.routes.draw do

  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
  root 'map#index'
  mount Raddocs::App => "/docs"

  resources :country, only: [:index, :show]
  resources :explore_data, only: [:index, :show]
  resources :about, only: [:index, :concept, :data, :data_analisys]
   namespace :api, defaults: {format: 'json'} do
    #scope module: :v1, constraints: APIVersion.new(version: 1) do
    scope module: :v1 do
      resources :layers, only: [:index]
      get '/share/:uid', to: 'share_urls#show'
      post '/share', to: 'share_urls#create'
    end
  end

end
