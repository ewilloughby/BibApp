## helpers
## https://github.com/plataformatec/devise/blob/master/lib/devise/controllers/helpers.rb

## see this about a strategy to use guest_user which I might need for Saving Works for a non-signed in user
## unless I can just do it all in sessions
# https://github.com/plataformatec/devise/wiki/How-To:-Create-a-guest-user

class Users::SessionsController < Devise::SessionsController
    # before_filter :configure_sign_in_params, only: [:create]
    
      require 'will_paginate/array'
    
      # methods are in application_controller, not sure if I need with Devise
      # but still need a way to start or query session
      #before_action :require_no_user, :only => [:new, :create]
      # don't think this is wanted as it directs user to logmein, but since logmein is inside firewall perhaps okay
      #before_action :require_user, :only => [:destroy]  
      
      #get 'saved', :to => 'users/sessions#saved', :as => 'saved'
      #get 'delete_saved', :to => 'users/sessions#delete_saved', :as => 'delete_saved'
      #get 'add_many_to_saved', :to => 'users/sessions#add_many_to_saved', :as => 'add_many_to_saved'   
      
      skip_authorize_resource :only => [:new, :create, :saved, :delete_saved, :add_many_to_saved, :destroy]
      skip_authorization_check :only => [:new, :create, :saved, :delete_saved, :add_many_to_saved, :destroy]
      
      # GET /resource/sign_in
       def new
         super
       end
      
       # POST /resource/sign_in
       def create
         logger.debug("\n\n ==== IN USERS::SESSIONCONTROLLER CREATE METHOD ======\n")
         # inspecting params here will include actual password,
         # next is preferred way to plug into this method 
         #super do |resource|
         #end
    
         # session fixation counter measure
         reset_session
         
         super
       end
      
       # DELETE /resource/sign_out
       def destroy
         logger.debug("\n\n ==== IN USERS::SESSIONCONTROLLER DESTROY METHOD ======\n")
         logger.debug(params.inspect)
         
         super
       end
       
       # this method was in UserSession in R3.2.18 and routes with saved_path
       def saved
    
         @export_styles = ["", "APA", "Chicago", "Harvard", "IEEE", "MLA", "Nature", "NLM", "NIH-PMCID"]
         
         @page = params[:page] || 1
         @rows = params[:rows] || 10
         @export = params[:export] ||= ''
         @export = '' unless @export_styles.collect{|x| x.downcase}.include?(@export)
         
         unless @export.blank?
           ce = WorkExport.new
           
           @works = Work.where(:id => session[:saved].all_works).sort_by {|w| [w.publication_date_year, w.first_author_sort]}.paginate(page: @page, per_page: @rows)
           
           # sorting by pub date year, then first author
           @works = ce.drive_csl(@export, @works.sort_by {|w| [w.publication_date_year, w.first_author_sort] })
           
         else
           
           @works = Work.where(:id => session[:saved].all_works).paginate(page: @page, per_page: @rows)
           
         end
         
       end
       
      
       protected
       
       def after_sign_in_path_for(resource)
         admin_index_path
       end
       
       # Serialize string instead of BSON
       # just curious if this does anything for me ?
        def self.serialize_into_session(record)
          #[record.to_key.map(&:to_s), record.authenticatable_salt]
          super
        end
       
    
      # You can put the params you want to permit in the empty array.
      # def configure_sign_in_params
      #   devise_parameter_sanitizer.for(:sign_in) << :attribute
      # end
    end