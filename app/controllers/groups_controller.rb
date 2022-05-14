class GroupsController < ApplicationController
  include GoogleChartsHelper
  include KeywordCloudHelper

  #Require a user be logged in to create / update / destroy
  #before_action :login_required, :only => [:new, :create, :edit, :update, :destroy, :hide]
  before_action :authenticate_user!, :only => [:new, :create, :edit, :update, :destroy, :hide]
  
  load_and_authorize_resource
  skip_authorize_resource :only => [:show, :index, :group_dashboard]
  # since I'm using check_authorization in application_controller
  skip_authorization_check :only => [:show, :index, :group_dashboard] 

  make_resourceful do
    build :all

    publish :xml, :json, :yaml, :attributes => [
        :id, :name, :url, :description,
        {:people => [:id, :name]}
    ]

    #Add a response for RSS
    response_for :show do |format|
      format.html #loads show.html.haml (HTML needs to be first, so I.E. views it by default)
      format.rss #loads show.rss.builder
    end

    before :index do
      @title = Group.model_name.human_pl
      # find first letter of group names (in uppercase, for paging mechanism)
      @a_to_z = Group.letters

      if params[:person_id]
        @person = Person.find(params[:person_id].split("-")[0])

        # Collect a list of the person's top-level groups for the tree view
        @top_level_groups = Array.new
        @person.memberships.active.select { |m| !m.group.hide? }.each do |m|
          @top_level_groups << m.group.top_level_parent
        end
        @top_level_groups.uniq!
      end

      @page = params[:page] || @a_to_z[0]
      @current_objects = Group.unhidden.sort_name_like("#{@page}%").order(:sort_name)
    end

    before :show do
      
      search( params.merge({'rows' => 15}) ) 

      @group = @current_object
      @title = @group.name
      work_count = @q.data['response']['numFound']
      
      @chart_urls = Array.new
      @work_counts = Array.new
      @years = Array.new
      @is_search = false
      
      facet_years = @facets[:years].compact

      # not sure why some are reversed years in facets which breaks Range to_a
      #year_array = facet_years.empty? ? [] : Range.new(facet_years.first.name, facet_years.last.name).to_a

      year_array = if facet_years.empty?
        []
      elsif facet_years.last.name > facet_years.first.name
        Range.new(facet_years.first.name, facet_years.last.name).to_a
      else
        Range.new(facet_years.last.name, facet_years.first.name).to_a
      end

      @years << year_array.last unless year_array.empty?

      # group only index
      query = '*:*'
      filter = ['active:true', "group_id:#{@group.id}", 'verified_works_count:[1 TO *]']
      rows = 400

      #@facets already exists so adding a key that wouldn't exist
      num = Random.rand(10...50000)
      @facets[:random_activepersons] = PeopleIndex.fetch(query, filter, rows, num)
 
      if work_count > 0
        #@chart_url = google_chart_url(@facets, work_count)
        @chart_urls << google_chart_api(@facets, work_count)
        @keywords = set_keywords(@facets)
        @work_counts[0] = work_count
      end
    end

    before :new do
      @groups = Group.unhidden.order_by_name
    end


    before :edit do
      #'editor' of group can edit that group
      #permit "editor of group"

      @groups = Group.unhidden.order_by_name
    end
  end

  def create

    @duplicategroup = Group.name_like(params[:group][:name]).first

    if @duplicategroup.nil?
     # @group = Group.find_or_create_by_name(params[:group])
      @group = Group.new(group_params)
      @group.hide = false
      @group.save

      respond_to do |format|
        flash[:notice] = t('common.groups.flash_create_success')
        format.html { redirect_to group_url(@group) }
      end
    else
      respond_to do |format|
        flash[:notice] = t('common.groups.flash_create_duplicate')
        format.html { redirect_to new_group_path }
      end
    end
  end

  def update

    authorize! :update, Group, message: "Not authorized to edit Groups"
    @group.update_attributes(group_params)
    
    respond_to do |format|
      flash[:notice] = t('common.groups.flash_update_success')
      format.html { redirect_to group_url(@group) }
    end
  end

  def hidden
    @hidden_groups = Group.hidden.order(:sort_name)
    @title = t('common.groups.hidden_groups')
  end

  def autocomplete
    respond_to do |format|
      format.json {render :json => json_name_search(params[:term].downcase, Group, 8)}
    end
  end

  def hide
    @group = Group.find(params[:id])

    #permit "editor on group", :group => @group

    children = @group.children.select { |c| !c.hide? }

    # don't hide groups with children
    if children.blank?
      @group.hide = true
      @group.save
      respond_to do |format|
        flash[:notice] = t('common.groups.flash_hide_success')
        format.html { redirect_to :action => "index" }
      end
    else
      respond_to do |format|
        flash[:error] = t('common.groups.flash_hide_failure_html', :children => child_list(children))
        format.html { redirect_to :action => "edit" }
      end
    end
  end

  def unhide
    @group = Group.find(params[:id])

    #permit "editor on group", :group => @group

    parent = @group.parent

    if parent.hide?
      respond_to do |format|
        flash[error] = t('common.groups.flash_unhide_failure_html', :parent_name => parent.name)
        format.html { redirect_to :action => "edit" }
      end

    end
    @group.hide = false
    @group.save
    respond_to do |format|
      flash[:notice] = t('common.groups.flash_unhide_success')
      format.html { redirect_to :action => "index" }
    end
  end

  def destroy
    #permit "admin"

    @group = Group.find(params[:id])

    #check memberships
    memberships = @group.memberships

    #check children
    children = @group.children

    if memberships.blank? and children.blank?
      @group.destroy
      respond_to do |format|
        flash[:notice] = t('common.groups.flash_destroy_success')
        format.html { redirect_to groups_path() }
      end
    elsif !memberships.blank?
      respond_to do |format|
        flash[:error] = t('common.groups.flash_destroy_failure_memberships')
        format.html { redirect_to :action => "edit" }
      end
    elsif children.present?
      respond_to do |format|
        flash[:error] = t('common.groups.flash_destroy_failure_children_html', :child_list => child_list(children))
        format.html { redirect_to :action => "edit" }
      end
    end
  end

  protected

  def child_list(children)
    items = children.collect {|c| "<li>#{c.name}</li>"}
    "<ul>#{items.join('')}</ul>"
  end

  private
  
  def group_params
    params.require(:group).permit(:name, :url, :description, :parent_id, :hide)
  end

end