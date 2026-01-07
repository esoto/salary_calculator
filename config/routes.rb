Rails.application.routes.draw do
  resources :salary_entries do
    collection do
      get :summary
    end
  end

  root "salary_entries#index"

  get "up" => "rails/health#show", as: :rails_health_check
end
