require 'bibapp_ldap'

class PeopleController < ApplicationController
  include GoogleChartsHelper
  include KeywordCloudHelper

  # Require a user be logged in to create / update / destroy
  #before_action :login_required, :only => [:new, :create, :edit, :update, :destroy, :batch_csv_show, :batch_csv_create]
  before_action :authenticate_user!, :only => [:new, :create, :edit, :update, :destroy, :batch_csv_show, :batch_csv_create]

  load_resource
  skip_authorization_check :only => [:index, :show, :find_person]

  make_resourceful do
    build :index, :new, :create, :show, :edit, :update, :destroy

    publish :xml, :json, :yaml, :attributes => [
        :id, :name, :first_name, :middle_name, :last_name, :prefix, :suffix, :phone, :email, :im, :office_address_line_one, :office_address_line_two, :office_city, :office_state, :office_zip, :research_focus, :active,
        {:name_strings => [:id, :name]},
        {:groups => [:id, :name]},
        {:contributorships => [:work_id]}]

    #Add a response for RSS
    response_for :show do |format|
      format.html #loads show.html.haml (HTML needs to be first, so I.E. views it by default)
      format.rss #loads show.rss.builder
      format.rdf
    end

    response_for :index do |format|
      format.html
      format.rdf
    end

    response_for :destroy do |format|
      format.html { redirect_to @return_path }
      format.xml { head :ok }
    end

    before :index do

      # for groups/people
      if params[:group_id]
        @group = Group.find_by_id(params[:group_id].split("-")[0])

        if params[:q]
          @current_objects = current_objects
        else
          @a_to_z = Array.new
          @group.people.each do |person|
            @a_to_z << person.last_name[0, 1].upcase
          end
          @a_to_z = @a_to_z.uniq
          @page = params[:page] || @a_to_z[0]
          @current_objects = @group.people.order("upper(last_name), upper(first_name)")
          @current_objects = @current_objects.where("upper(last_name) like ?", "#{@page}%") unless @page == 'all'
        end

        @title = "#{@group.name} - #{NameString.model_name.human_pl}"
      else

        if params[:q]
          @current_objects = current_objects
        else
          @a_to_z = Person.letters
          @page = params[:page] || @a_to_z[0]
          @current_objects = Person.where("upper(last_name) like ?", "#{@page}%").order("upper(last_name), upper(first_name)")
        end

        @title = Person.model_name.human_pl
      end
    end

    before :new do
      authorize!(:admin, Person)
      if params[:q]
        begin
          @ldap_results = BibappLdap.instance.search(params[:q])
        rescue BibappLdapConfigError
          @fail_message = t('common.people.ldap_fail_configuration')
        rescue BibappLdapConnectionError
          @fail_message = t('common.people.ldap_fail_authentication')
        rescue BibappLdapTooManyResultsError
          @fail_message = t('common.people.ldap_fail_too_many')
        rescue BibappLdapError => e
          @fail_message = e.message
        end
        if @ldap_results.nil?
          @fail = true
        else
          @ldap_results.compact!
        end
      end
      @title = t('common.people.new')
    end

    before :show do
      search(params)
      @person = @current_object
      work_count = @q.data['response']['numFound']
      
      @chart_urls = Array.new
      @work_counts = Array.new
      @years = Array.new
      
      facet_years = @facets[:years].compact
      year_array = facet_years.empty? ? [] : Range.new(facet_years.first.name, facet_years.last.name).to_a
      @years << year_array.last unless year_array.empty?
      
      @authstats = {}
      
      if work_count > 0
        #@chart_url = google_chart_url(@facets, work_count)
        @chart_urls << google_chart_api(@facets, work_count)
        @keywords = set_keywords(@facets)
        @work_counts[0] = work_count # moved this from above if > 0
      end
      
      # Collect a list of the person's top-level groups for the tree view
      @top_level_groups = Array.new
      @person.memberships.active.collect { |m| m unless m.group.hide? }.each do |m|
        @top_level_groups << m.group.top_level_parent unless m.nil? or m.group.top_level_parent.hide?
      end
      @top_level_groups.uniq!
    end

    before :destroy do
      authorize!(:admin, Person)
      person = Person.find(params[:id])
      @return_path = params[:return_path] || people_url
      person.destroy if person
      #flash[:notice] = "#{person.display_name} was successfully deleted."
    end

    before :edit do
      @title = t('common.people.edit_title', :name => @person.display_name)
    end

  end

  def create

    #Check if user hit cancel button
    if params['cancel']
      #just return back to 'new' page
      respond_to do |format|
        format.html { redirect_to new_person_url }
        format.xml { head :ok }
      end

    else #Only perform create if 'save' button was pressed

      @person = Person.new(person_params)
      @dupeperson = Person.find_by_uid(@person.uid)

      if @dupeperson.nil?
        respond_to do |format|
          if @person.save
            flash[:notice] = t('common.people.flash_create_success')
            format.html { redirect_to new_person_pen_name_path(@person.id) }
            #TODO: not sure this is right
            format.xml { head :created, :location => person_url(@person) }
          else
            flash[:warning] = t('common.people.flash_create_field_missing')
            format.html { render :action => "new" }
            format.xml { render :xml => @person.errors.to_xml }
          end
        end
      else
        respond_to do |format|
          flash[:error] = t('common.people.flash_create_person_exists_html', :url => person_path(@dupeperson.id))
          format.html { render :action => "new" }
          #TODO: what will the xml response be?
          #format.xml  {render :xml => "error"}
        end
      end
    end
  end

  def update

    #@person = Person.find(params[:id])
    authorize!(:admin, @person)

    #Check if user hit cancel button
    if params['cancel']
      #just return back to 'new' page
      respond_to do |format|
        format.html { redirect_to person_url(@person) }
        format.xml { head :ok }
      end

    else #Only perform create if 'save' button was pressed
      peeps = person_params
      @person.update(peeps)
      
      if @person.errors.any?
        logger.debug("\n\n ============ PERSON_UPDATE_ERRORS ==============\n")
        @person.errors.full_messages.each do |msg|
          logger.debug(msg)
        end
      end
      
      respond_to do |format|
        if @person.save
          flash[:notice] = t('common.people.flash_update_success')
          #format.html { redirect_to new_person_pen_name_path(@person.id) }
          format.html { redirect_to edit_person_path(@person.id) }
          format.xml { head :created, :location => person_url(@person) }
        else
          flash[:warning] = t('common.people.flash_update_failure')
          format.html { render :action => "new" }
          format.xml { render :xml => @person.errors.to_xml }
        end
      end
    end
  end

  def load_reftype_chart
    @person = Person.find(params[:person_id])

    #generate the google chart URI
    #see http://code.google.com/apis/chart/docs/making_charts.html
    #
    chd = "chd=t:"
    chl = "chl="
    chdl = "chdl="
    chdlp = "chdlp=b|"
    @person.publication_reftypes.each_with_index do |r, i|
      percent = (r.count.to_f/@person.works.size.to_f*100).round.to_s
      chd += "#{percent},"
      ref = r[:type].to_s == 'BookWhole' ? 'Book' : r[:type].to_s
      chl += "#{ref.titleize.pluralize}|"
      chdl += "#{percent}% #{ref.titleize.pluralize}|"
      chdlp += "#{i.to_s},"
    end
    chd.chop!
    chl.chop!
    @chart_url = "http://chart.apis.google.com/chart?cht=p&chco=346090&chs=350x100&#{chd}&#{chl}"

    render :update do |page|
      page.replace_html "loading_reftype_chart", "<img src='#{@chart_url}' alt='work-type chart' style='margin-left: -50px;margin-bottom:20px;' />"
    end

  end

  def batch_csv_show
    authorize!(:admin, Person)
  end

  def batch_csv_create
    authorize!(:admin, Person)
    @message = ''
    begin
      filename = params[:person][:data].original_filename
      str = params[:person][:data].read
      unless str.is_utf8?
        encoding = CMess::GuessEncoding::Automatic.guess(str)
        unless encoding.nil? or encoding.empty? or encoding==CMess::GuessEncoding::Encoding::UNKNOWN
          str = Iconv.iconv('UTF-8', encoding, str).to_s
        else
          flash[:notice] = t('common.people.flash_batch_csv_create_bad_encoding')
          @message = t('common.people.file_unconvertible')
        end
      end
      if @message.empty?
        BatchUpload::CsvPeople.new(str, current_user.id, filename).delay.perform
        @message = t('common.people.file_accepted')
      end
    rescue Exception => e
      flash[:notice] = t('app.exception_with_message', :message => e.to_s)
      @message = t('common.people.batch_csv_error')
    end

    render 'batch_csv_show'
  end

  def person_params
    params.require(:person).permit(:uid, :first_name, :middle_name, :last_name, :active, :suffix, :display_name, :start_date, :end_date, :email, :phone, :postal_address, :im, :staff_note, :research_focus, :id)
  end


end
