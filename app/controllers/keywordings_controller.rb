class KeywordingsController < ApplicationController
  
  #Require a user be logged in to create / update / destroy
  #before_action :login_required, :only => [ :new, :create, :edit, :update, :destroy ]
  before_action :authenticate_user!, :only => [ :new, :create, :edit, :update, :destroy ]
  
  make_resourceful do
    build :all
  end
  
end
