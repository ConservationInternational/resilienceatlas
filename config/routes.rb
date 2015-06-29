Rails.application.routes.draw do

  root 'map#index'

  resources :country, only: [:index, :show]
  resources :explore_data, only: [:index, :show]
  resources :about, only: [:index, :concept, :data, :data_analisys]

end
