Rails.application.routes.draw do

  # Admin routes
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)

  # API docs
  mount Raddocs::App => "/docs"

  # Aplication
  root 'welcome#index'
  get 'map', to: 'map#index'
  get 'about', to: 'about#index'

end
