class PublishersController < ApplicationController
  include PubCommonHelper

  #Require a user be logged in to create / update / destroy
  #before_action :login_required, :only => [:new, :create, :edit, :update, :destroy]
  before_action :authenticate_user!, :only => [:new, :create, :edit, :update, :destroy]
  
  load_and_authorize_resource :except => [:index, :show] 
  skip_authorization_check :only => [:index, :show] 

  make_resourceful do
    build :index, :show, :new, :edit, :create, :update

    publish :yaml, :xml, :json, :attributes => [
            :id, :name, :url, :sherpa_id, :romeo_color, :copyright_notice, :publisher_copy, {
                    :publications => [:id, :name]
            }, {
                    :authority => [:id, :name]
            }, {
                    :works => [:id]
            }
    ]

    #Add a response for RSS
    response_for :show do |format|
      format.html #loads show.html.haml (HTML needs to be first, so I.E. views it by default)
      format.rss #loads show.rss.builder
    end

    response_for :update do |format|
      format.html do
        if params[:save_and_list]
          redirect_to publishers_url(:page => @publisher.name.first.upcase)
        else
          redirect_to publisher_url(@publisher)
        end
      end
      format.rss
    end

    before :index do
      @title = Publisher.model_name.human_pl
      # find first letter of publisher name (in uppercase, for paging mechanism)
      @a_to_z = Publisher.letters(true)

      if params[:q]
        @current_objects = current_objects
      else
        @page = params[:page] || @a_to_z[0]
        @current_objects = Publisher.authorities.sort_name_like("#{@page}%").order('sort_name')
      end
    end

    before :show do
      search(params)
      @publication = @current_object

      @authority_for = Publisher.for_authority(current_object.id).order_by_name
    end

    before :new do
      #Anyone with 'editor' role (anywhere) can add publishers
      #permit "editor"

      @publishers = Publisher.authorities.order_by_name
      @publications = Publication.authorities.order_by_name
    end

    before :create do
      #Anyone with 'editor' role (anywhere) can add publishers
      authorize! :create, Publisher, message: "Not authorized to create"
    end

    before :edit do
      #Anyone with 'editor' role (anywhere) can update publishers
      authorize! :update, Publisher, message: "Not authorized to edit"

      @publishers = Publisher.order_by_name
      @publications = Publication.authorities.order_by_name
    end

    before :update do
      #Anyone with 'editor' role (anywhere) can update publishers
      authorize! :update, Publisher, message: "Not authorized to update"
    end
  end

  def authorities
    #Only group editors can assign authorities
    #permit "editor of Group"

    @a_to_z = Publisher.letters

    if params[:q]
      @current_objects = current_objects
    else
      @page = params[:page] || @a_to_z[0]
      @current_objects = Publisher.authorities.sort_name_like("#{@page}%").order(:sort_name).
              includes(:publications)
    end

    #Keep a list of publications in process in session[:publication_auths]
    @pas = Publisher.includes(:publications, :authority).find(session[:publisher_auths] || Array.new)
  end

  def add_to_box
    add_to_box_generic(Publisher)
  end

  def remove_from_box
    remove_from_box_generic(Publisher)
  end

  def update_multiple
    update_multiple_generic(Publisher)

  end

  def autocomplete
    respond_to do |format|
      format.json {render :json => json_name_search(params[:term].downcase, Publisher, 8)}
    end
  end

  private
  def publisher_params
    params.require(:publisher).permit(:name, :url, :sherpa_id, :publisher_source_id, :authority_id, :romeo_color)
  end

  def current_objects
    if params[:q]
      query = '%' + params[:q] + '%'
    end
    @current_objects ||= current_model.name_like(query)
  end
end