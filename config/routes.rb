Rails.application.routes.draw do

  root 'map#index'
  
  resources :topics, only: [:index, :show]

end
