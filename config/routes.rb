Rails.application.routes.draw do

  devise_for :users, path_prefix: 'my', controllers: { registrations: 'registrations' }
  devise_scope :user do
    delete '/my/users/sign_out', to: 'devise/sessions#destroy', as: :delete_user_session
  end

  resources :users
  resources :organizations do
    member do
      get :rename
      patch :rename, action: :update_rename
    end
  end
  resources :activity, only: [:index, :show]
  namespace :outreach do
    root to: "campaigns#index"
    resources :campaigns do
      member do
        post :close
      end
      resources :enrollments, only: [:create], controller: "campaign_enrollments"
    end
    resources :plans do
      resources :steps, only: [:create, :destroy], controller: "plan_steps"
    end
    resources :enrollments, only: [:show, :create] do
      member do
        post :complete_step
        post :send_message
        post :simulate_reply
        post :pause
        post :resume
        post :reenroll
        post :dev_reset
        post :toggle_dev_mode
        post :return_to_step
      end
    end
    post "customers/:customer_id/promote_to_lead", to: "customer_promotions#create", as: :promote_customer
  end

  resources :discovery, only: [:index, :show] do
    member do
      patch :update_captured_business
      post :promote_to_potential
      post :archive
      post :unarchive
      delete :destroy
      post :check_google_places
      post :select_google_place
      post :score
      get :score_card
    end
    collection do
      post :fetch_wa_sos
      post :save_businesses
      get :captured_list
      patch :sos_defaults, action: :update_sos_defaults
      get "runs/:run_id/load", action: :load_discovery_run, as: :load_discovery_run
    end
  end
  resources :offerings

  get 'new_custom_lead', to: 'leads#new_custom_lead'

  resources :settings, only: [:index, :show]
  get '/settings/transfer_customers', to: 'settings#transfer_customers', as: 'settings_transfer_customers'
  post '/settings/transfer_customers', to: 'settings#transfer_customers', as: 'process_transfer_customers'
  patch '/settings/organization_modules', to: 'settings#update_modules', as: :update_organization_modules
  patch '/settings/discovery', to: 'settings#update_discovery', as: :update_discovery_settings
  post '/settings/toggle_customer_offerings_section', to: 'settings#toggle_customer_offerings_section', as: :settings_toggle_customer_offerings_section
  post '/settings/toggle_customer_revenue_section', to: 'settings#toggle_customer_revenue_section', as: :settings_toggle_customer_revenue_section

  root to: "root#show"

  resources :home, only: [:index, :show] do
    member do
      get '/home/:id/invoices_modal', to: 'home#show_invoices_modal', as: 'invoices_modal'
    end
  end
  get 'home/index'
  get 'home/show' => 'home#show'
  get 'home/new' => 'home#new'

  resources :contacts
  resources :notes do
    get 'edit_notes', on: :member
  end

  resources :customers do
    collection do
      post :import
    end
    member do
      patch :move
      put :sort
      get 'invoices_modal', to: 'home#show_invoices_modal', as: 'invoices_modal'
      get :invoices
      post :start_fetch_invoices
      post :start_fetch_sales_receipts
      post :start_fetch_customer
      delete :delete_invoices
    end
  end

  resources :lists do
    member do
      put :sort
    end
  end

  resources :potentials do
    member do
      post :start_fetch_invoices
      post :start_fetch_sales_receipts
      post :start_fetch_customer
      delete :delete_invoices
    end
  end

  resources :leads, only: [:index, :new, :create]

  resources :stats

  resources :archived, only: [:index]

  resources :setups, only: [:index, :new, :create, :show]

  get 'download_pdf', to: 'customers#download_pdf'

  get '/search', to: 'application#search'
  post '/switch_organization', to: 'organization_switches#create', as: :switch_organization
  get 'customers/:id/existing_edit', to: 'customers#existing_edit', as: 'existing_edit_customer'

  resources :privacy, only: [:index, :show]
  resources :eula, only: [:index, :show]

  get 'quickbooks/auth', to: 'quickbooks#auth', as: :quickbooks_auth
  get 'oauth/callback', to: 'quickbooks#callback', as: :quickbooks_callback
  post 'refresh_quickbooks_token', to: 'settings#refresh_token'
  patch '/settings/update_token', to: 'settings#update_token', as: :update_token
  patch '/settings/quickbooks_integration', to: 'settings#update_quickbooks_integration', as: :update_quickbooks_integration
  post '/settings/disconnect_quickbooks', to: 'settings#disconnect_quickbooks', as: :disconnect_quickbooks
  patch '/settings/outreach_sms_channel', to: 'settings#update_outreach_sms_channel', as: :update_outreach_sms_channel
  patch '/settings/outreach_sms_messages', to: 'settings#update_outreach_sms_messages', as: :update_outreach_sms_messages

  post '/twilio/incoming_sms', to: 'twilio_webhooks#incoming_sms', as: :twilio_incoming_sms

  resources :home do
    post :start_fetch_invoices, on: :member
    post :start_fetch_sales_receipts, on: :member
    post :start_fetch_customer, on: :member
    delete :delete_invoices, on: :member
  end

  get 'home/download/download_invoice_pdf', to: 'home#download_invoice_pdf', as: :download_invoice_pdf_home
  get 'home/download/download_sales_receipt_pdf', to: 'home#download_sales_receipt_pdf', as: :download_sales_receipt_pdf_home
  get 'home/download/download_refund_receipt_pdf', to: 'home#download_refund_receipt_pdf', as: :download_refund_receipt_pdf_home
end
