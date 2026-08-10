Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resources :features, only: %i[index show new create edit update destroy], param: :id do
    collection do
      post :verify
    end
  end

  resources :discoveries, only: [:index], path: "discover" do
    collection do
      post :scan
      get :verses
      get :dictionary
      get :file_stats_children
      get :file_stats_characters
    end
  end

  resources :numbers, only: %i[index show], param: :id do
    member do
      get :preview
    end
  end

  get "scripture", to: "scriptures#show", as: :scripture
  get "scripture/:book/chapters/:chapter", to: "scriptures#chapter", as: :scripture_chapter

  root "pages#home"
end
