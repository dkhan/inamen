Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resources :features, only: %i[index show], param: :id do
    collection do
      post :verify
    end
  end

  root "pages#home"
end
