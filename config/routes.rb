Rails.application.routes.draw do

  devise_for :users
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  root 'map#index'

  resources :country, only: [:index, :show]
  resources :explore_data, only: [:index, :show]
  resources :about, only: [:index, :concept, :data, :data_analisys]

end
