Rails.application.routes.draw do
  devise_for :users
  root to: "pages#home"

  get "/profile", to: "pages#profile"
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

  # member do...end permet d'ajouter une action custom sur une ressource existante.
  # `get 'export_pdf'` génère : GET /researches/:id/export_pdf → researches#export_pdf
  # et le helper export_pdf_research_path(@research).
  resources :researches, only: [:new, :create, :show, :edit, :update, :destroy] do
    member do
      get 'export_pdf'
    end
  end
  resources :maps, only: [:index, :show]
  resources :guest_searches, only: [:new, :create] do
    get 'results', on: :collection, to: 'guest_searches#results'
  end

  resources :chats, only: [:index, :show, :destroy, :update]

  resources :messages, only: [:create, :destroy] do
    collection do
      post :stream
    end
  end
end
