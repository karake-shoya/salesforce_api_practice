Rails.application.routes.draw do
  resources :jobs do
    collection do
      post :test_salesforce_connection
      get :test_client_credentials
      post :sync_all_to_client_credentials
      get :deleted  # 削除済み一覧
      delete :cleanup_old_deleted  # 古いレコードのクリーンアップ
    end
    member do
      post :sync_to_client_credentials
      patch :restore  # 復元
    end
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "jobs#index"
end
