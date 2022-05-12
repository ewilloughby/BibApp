class SearchController < ApplicationController

  skip_authorize_resource
  skip_authorization_check

  def index
    # Default BibApp search method - ApplicationController
    search(params)
    #byebug

    respond_to do |format|
      format.html # Do HTML
      format.json
      format.yaml
      format.xml
      format.rdf
    end
  end

  def advanced
    
    normal_fields = [:title, :authors, :groups, :issn_isbn, :start_date, :end_date, :created_start, :created_end]
    fields = normal_fields << :keywords
    if !fields.detect { |f| params[f].present? }
      @q = nil
      return
    end
    
    
    if params[:orcid_id].present?
      @q = nil
      orcid_id = params[:orcid_id]
      perp = Person.find_by_orcid_id(orcid_id)
      redirect_to person_path(:id => perp['id']) if perp
      
    else

      logger.debug("\n\n ======== START_ADVANCED_SEARCH with params: ===========\n")
      logger.debug(params.inspect)
      # Process the params and redirect to /search
      @q = Array.new

      #logger.debug(@q.inspect)
      ## Add keywords to query
      #if !params[:keywords].nil? && !params[:keywords].empty?
      #  @q << params[:keywords]
      #end

      #Add 'normal' fields to query
      normal_fields.each do |field|
        next if field == :created_start || field == :created_end || field == :start_date || field == :end_date
        if params[field].present?
          
          if field == :identifier
            str = escape_solr_reserved(params[:identifier].to_s.downcase)
            @q << "identifier:#{str}"
            
          elsif field == :title
            str = params[:title].to_s
            if str.include?('"')
              tmp = str.gsub(/"/, '\"')
              regx = /^(?<start>.*)?\\"(?<term>.*)?\\"(?<last>.*)$/
              m = tmp.match(regx)
              str = "#{m['start']}\"#{m['term'].gsub(/\s/,'+')}\"#{m['last']}" if m
            end
            str.gsub!(/:/, '\:')
            @q << "title:#{str}"
          
          else
            @q << "#{field}:#{params[field]}"
          end
          
          logger.debug(params[field].inspect)
        end
      end
      
      # keywords will become the default solr search which is of type text, a solr copyfield for a real word-based search
      # not sure why the above doesn't or didn't work.
      unless @q.nil?
        @q = @q.collect{ |qry|
          if qry.index('keywords:') == 0
            qry.split(/^keywords:/)[1]
          else
            qry
          end
        }
      end
                
      # Add year to query
      start_date = params[:start_date].present? ? params[:start_date] : "*"
      end_date = params[:end_date].present? ? params[:end_date] : "*"

      # Only if we have a non-default start_date or end_date add it to @q
      unless start_date == "*" and end_date == "*"
        @q << "year:[#{start_date} TO #{end_date}]"
        params.delete(:start_date)
        params.delete(:end_date)
      end

      crange = params[:created_start].present? ? set_create_date_range : ''  
      @q << crange unless crange.empty?

      logger.debug("\n\n ========== SOLR_QUERY ============\n")
      logger.debug(@q.inspect)
      redirect_to search_path(q: @q.join(", "))
    end
  end

end