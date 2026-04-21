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

  # Wizard de création de recherche (gem wicked, 4 étapes) — utilisateur connecté.
  # GET  /recherche/nouveau    → démarre un nouveau wizard (vide la session wizard)
  # GET  /search_steps/:id     → affiche l'étape courante (:id = nom de l'étape)
  # PATCH /search_steps/:id   → sauvegarde l'étape et avance
  get 'recherche/nouveau', to: 'search_steps#new_wizard', as: :new_research_wizard
  resources :search_steps, only: [:show, :update]

  # Wizard de création de recherche (gem wicked, 4 étapes) — visiteur non connecté.
  # Même parcours que le wizard utilisateur mais sans authentification.
  # GET  /recherche/invite/nouveau → démarre un nouveau wizard invité
  # GET  /guest_search_steps/:id  → affiche l'étape courante
  # PATCH /guest_search_steps/:id → sauvegarde l'étape et avance
  get 'recherche/invite/nouveau', to: 'guest_search_steps#new_wizard', as: :new_guest_wizard
  resources :guest_search_steps, only: [:show, :update]

  # Redirige /researches/new vers le wizard Wicked pour éviter que Rails
  # ne l'interprète comme show avec id="new" (ce qui lèverait un RecordNotFound).
  get 'researches/new', to: redirect('/recherche/nouveau')

  # member do...end permet d'ajouter une action custom sur une ressource existante.
  # `get 'export_pdf'` génère : GET /researches/:id/export_pdf → researches#export_pdf
  # et le helper export_pdf_research_path(@research).
  resources :researches, only: [:show, :edit, :update, :destroy] do
    member do
      get 'export_pdf'
    end
  end
  resources :maps, only: [:index, :show] do
    # Route collection : /maps/results – affiche les 5 villes d'une recherche sur la carte.
    # Doit être une collection (pas un member) pour ne pas être confondue avec /maps/:id.
    collection do
      get 'results'
    end
  end
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
