Rails.application.routes.draw do
  devise_for :users
  root to: "pages#home"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
  
resources :users, only: [] do
  member do
    get 'profile', to: 'users#show'
    get 'profile/edit', to: 'users#edit'
    patch 'profile', to: 'users#update'
    delete 'profile', to: 'users#destroy'
  end
end

  resources :researches, only: [:new, :create, :show, :edit, :update, :destroy]
  resources :maps, only: [:index, :show]
  resources :guest_searches, only: [:new, :create] do
    get 'results', on: :collection, to: 'guest_searches#results'
  end

  resources :chats, only: [:index, :show, :destroy, :update]

  resources :messages, only: [:create, :destroy]
end

