Bibapp::Application.routes.draw do


  devise_for :users, path_names: {sign_in: 'login', sign_out: 'logout'}, controllers: { sessions: 'users/sessions' } 
  devise_scope :user do
    get 'saved', :to => 'users/sessions#saved', :as => 'saved'
    get 'delete_saved', :to => 'users/sessions#delete_saved', :as => 'delete_saved'
    get 'add_many_to_saved', :to => 'users/sessions#add_many_to_saved', :as => 'add_many_to_saved'   
  end

  def make_routes
    resources :works do
      collection do
        get :orphans
        delete :destroy_multiple
        post :orphans_delete
        get :shared
      end
      member do
        get :add_to_saved
        get :remove_from_saved
        put :change_type
      end

      resources :attachments
    end

    #####
    # Person routes
    #####
    resources :people do
      collection do
        get :batch_csv_show
        post :batch_csv_create
      end
      resources :attachments
      resources :works
      resources :groups
      resources :pen_names
      resources :memberships
      resources :roles do
        collection do
          get :new_admin
          get :new_editor
        end
      end
      resources :keywords do
        collection do
          get :timeline
        end
      end
    end

    #####
    # Group routes
    #####
    # Add Auto-Complete routes for adding new groups
    resources :groups do
      collection do
        get :autocomplete
        get :hidden
      end
      member do
        get :hide
        get :unhide
      end
      resources :works
      resources :people
      resources :roles do
        collection do
          get :new_admin
          get :new_editor
        end
      end
      resources :keywords do
        collection do
          get :timeline
        end
      end
    end

    #####
    # Membership routes
    #####
    # Add Auto-Complete routes
    resources :memberships do
      collection do
        put :create_multiple
        post :sort
        post :ajax_sort
        post :search_groups
      end
    end

    #####
    # Contributorship routes
    #####
    resources :contributorships do
      collection do
        get :admin
        get :archivable
        put :act_on_multiple
      end

      member do
        put :verify
        put :deny
      end
    end
    #####
    # Publisher routes
    #####
    resources :publishers do
      collection do
        get :authorities
        put :update_multiple
        get :add_to_box
        get :remove_from_box
        get :autocomplete
      end
    end

    #####
    # Publication routes
    #####
    resources :publications do
      collection do
        get :authorities
        put :update_multiple
        get :add_to_box
        get :remove_from_box
        get :autocomplete
      end
    end

    ####
    # User routes
    ####
    # Make URLs like /user/1/password/edit for Users managing their passwords
    resources :users do
      resources :imports do
        member do
          post :create_pen_name
          post :destroy_pen_name
        end
      end
      resource :password
      collection do
        get 'activate(/:activation_code)', :to => 'users#activate', :as => 'activate'
      end
      member do
        get :update_email
        post :request_update_email
      end
    end

    ####
    # Import routes
    ####
    resources :imports do
      resource :user
      resources :attachments
    end

    ####
    # Search route
    ####
    get 'search', :to => 'search#index', :as => 'search'
    get 'search/advanced', :to => 'search#advanced', :as => 'advanced_search'

    ####
    # Saved routes
    ####
    # Commenting saved routes out for now - references authlogic user_sessions
    #get 'saved', :to => 'user_sessions#saved', :as => 'saved'
    #get 'sessions/delete_saved', :to => 'user_sessions#delete_saved',
    #      :as => 'delete_saved'
    #get 'sessions/add_many_to_saved', :to => 'user_sessions#add_many_to_saved',
    #      :as => 'add_many_to_saved'
    ####
    # Authentication routes
    ####
    # Make easier routes for authentication (via restful_authentication)
    #get 'signup', :to => 'users#new', :as => 'signup'
    #get 'login', :to => 'user_sessions#new', :as => 'login'
    #get 'logout', :to => 'user_sessions#destroy', :as => 'logout'
    #get 'activate/:activation_code', :to => 'users#activate', :as => 'activate'

    ####
    # DEFAULT ROUTES
    ####
    # Install the default routes as the lowest priority.
    resources :name_strings do
      collection do
        get :autocomplete
      end
    end
    resources :memberships
    resources :pen_names do
      collection do
        post :create_name_string
        post :live_search_for_name_strings
        post :ajax_add
        post :ajax_destroy
      end
    end
    resources :keywords
    resources :keywordings
    resources :passwords
    resources :attachments do
      collection do
        get :add_upload_box
      end
    end

    # Default homepage to works index action
    #root :to => 'works#index'
    root to: 'works#index', as: 'default_home'
    
    get 'citations', :to => 'works#index'

    resource :user_session

    resources :authentications
    #get '/auth/:provider/callback' => 'authentications#create'
    get '/admin/index' => "admin#index"
    get 'admin/duplicates' => "admin#duplicates"
    get 'admin/ready_to_archive' => "admin#ready_to_archive"
    get 'admin/update_sherpa_data' => "admin#update_sherpa_data"
    get 'admin/deposit_via_sword' => "admin#deposit_via_sword"
    get 'admin/update_publishers_from_sherpa' => "admin#update_publishers_from_sherpa"

    get 'roles/index' => "roles#index"
    get 'roles/destroy' => "roles#destroy"
    get 'roles/create' => "roles#create"
    get 'roles/new_admin' => "roles#new_admin"
    get 'roles/new_editor' => "roles#new_editor"

    #Static Routes
    get "/about" => 'static#about', :as => 'about'
    get "/faq" => 'static#faq', :as => 'faq'

    #Contact Us
    # had to modify second, from :as => contact since it was ALSO being used in get
    get 'contact' => 'contact_mailer#new', :as => 'contact', :via => :get
    post 'contact' => 'contact_mailer#create', :as => 'post_contact', :via => :post
  end

  if I18n.available_locales.many?
    locale_regexp = Regexp.new(I18n.available_locales.join('|'))
    scope "(:locale)", :locale => locale_regexp do
      make_routes
    end
    #uncomment to make multi-locale version able to direct locale-less routes as well
    #make_routes
  else
    make_routes
  end


end
