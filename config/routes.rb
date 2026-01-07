Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resources :registrations, only: [ :new, :create ]

  get "dashboard", to: "dashboard#show"
  root "dashboard#show"

  resources :salary_entries do
    collection do
      get :summary
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
