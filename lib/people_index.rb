## INDEX FOR PEOPLE
## INDEX FOR PEOPLE

require 'solr'
class PeopleIndex

  #### Solr ####

  # FOR PEOPLE, added JUNE 26, 2015
  # CONNECT
  # SOLRPEOPLECONN lives in initializers
  
  #SOLR_PEOPLE_PATH = 'people'
  #SOLR_PEEP_URL = "http://127.0.0.1:#{SOLR_PORT}/solr/#{SOLR_PEOPLE_PATH}" unless defined? SOLR_URL
  #SOLRPEOPLECONN = Solr::Connection.new(SOLR_PEEP_URL)

  # SEARCH

  # DELETE INDEX - Very long process
  # @TODO: Learn how to use Solr "replication"
  ## persons.each{|c| PeopleIndex.remove_from_solr(c)}

  # REINDEX - Very long process
  # @TODO: Learn how to use Solr "replication"
  ## persons.each{|c| PeopleIndex.update_solr(c)}

  SOLR_PEOPLEMAPPING = {
    
      :id => :id, # is persons id
      :first_name => :first_name,
      :middle_name => :middle_name,
      :last_name => :last_name,
      :start_date => Proc.new {|perp| perp.start_date.nil? ? nil : perp.start_date.to_time.utc.iso8601},
      :end_date => Proc.new {|perp| perp.end_date.nil? ? nil : perp.end_date.to_time.utc.iso8601},
      :machine_name => :machine_name,
      
      #:display_name => :display_name,
      :display_name => Proc.new {|perp| perp.last_first_middle},
      
      :verified_works_count => Proc.new {|perp| perp.works_count},
      :research_focus => Proc.new { |perp| perp.person_research_focus},
      :group_id => Proc.new { |perp| perp.group_ids.collect{|x| x} },
      
      #:aid => :aid,
      #:height => :height,
      #:width => :width,
      #:data_file_name => :data_file_name,
      :people_data => Proc.new { |perp| perp.to_solr_data },
      :author_stats => Proc.new { |perp| perp.solr_author_stats },
      
      #Person's active status in separate field for filtering
      :active => :active,
      :created_at => :created_at

  }

  # to delete a single person
  # the id is the record to be deleted which can be retrieved by using a query_param and filter such as
  # to find the ID
  # query_params = { query: ["last_name:Some", "first_name:First"], filter_queries: [], field_list: ['*'], rows: 15}
  # q = SOLRPEOPLECONN.send(Solr::Request::Standard.new(query_params))
  # record = PeopleIndex.process_response(q)
  #
  def self.delete_by_person_id(id)
    SOLRPEOPLECONN.delete_by_query("id:#{id}")
    SOLRPEOPLECONN.optimize
  end

  #Re-index *everything* in Solr
  #  This method is useful in case your Solr index
  #  gets out of sync with your DB
  def self.index_all
    #Delete all existing records in Solr
    SOLRPEOPLECONN.delete_by_query('*:*')

    #Reindex all again
    #records = Person.all

    ##Do a batch update, 100 records at a time...wait to commit till the end.
    #records.each_slice(100) do |records_slice|
    #  batch_update_solr(records_slice, false)
    #end
    
    Person.find_in_batches(batch_size: 50) do |records_slice|
      batch_update_solr(records_slice, false) 
    end
    

    # not using COMMIT ?? with SOLR 6.2
    #SOLRPEOPLECONN.commit
    # spell suggestions as well not using
    #PeopleIndex.build_spelling_suggestions
  end

  def self.build_spelling_suggestions
    SOLRPEOPLECONN.send(Solr::Request::Spellcheck.new(:command => "rebuild", :query => "physcs"))
  end

  #Update a single record in Solr
  # (for bulk updating, use 'batch_update_solr', as it is faster)
  # changing to false, and actually commiting out commits for SOLR 6.2
  # CAUTION. running PeopleIndex.update_solr will not update group memberships (instead need to run xx.update_solr on person instance)
  def self.update_solr(record, commit_records=false)
    if Person.exists?(record.id)
      
      hsh = IndexAtomicUpdates.from_solr_get(record.id, 'People')
      if hsh.key?(:no_results)
        
        doc = solr_doc_from_record(record)
        
        doc[:created_at] = doc[:created_at].to_s(:db).sub(/\s/,'T').concat('Z') 
        result = SOLRPEOPLECONN.add(doc)
        
        Rails.logger.debug("ADDING PEOPLE DOC ===============\n")
        Rails.logger.debug(result.inspect) if defined?(result)
        
        
      else
        
        Rails.logger.debug("\n\n ============ PEOPLE_INDEX_UPDATINGS_SOLR: Index.update_solr UPDATE_EXISTING_PERSON via PARTIAL ============\n")
        jsondoc = BibappSolrPersonUpdate.update_person(record, hsh)
        
        result = '' 
        unless jsondoc.to_s.empty? # jsondoc would be empty if error 
          if hsh.key?('_version_')
            result = IndexAtomicUpdates.update_doc(jsondoc, 'people', hsh['_version_'])
          else
            result = IndexAtomicUpdates.update_doc(jsondoc, 'people')
          end
          
          Rails.logger.debug("Returned RESULTS from SOLR_PEOPLE_UPDATE =========\n")
          Rails.logger.debug(result.inspect)
          
        else
          Rails.logger.debug("\n\n ============== SOLR_PEOPLE UPDATE nothing to do ==========\n")
        end
        
        
      end
      
    else
       Rails.logger.debug("\n\n ============ PEOPLE_INDEX_UPDATINGS_SOLR person with id: #{record.id} does NOT EXIST")
    end  

  end

  #Batch update several records with a single request to Solr
  # change to false
  def self.batch_update_solr(records, commit_records=false)
    docs = records.collect do |record|
      solr_doc_from_record(record)
    end

    #Send one update request for all docs!
    request = Solr::Request::AddDocument.new(docs)
    SOLRPEOPLECONN.send(request)
    # SOLRPEOPLECONN.commit if commit_records
  end

    # can run this from Console for testing, PeopleIndex.solr_doc_from_record(w)
  def self.solr_doc_from_record(record)
      Solr::Importer::Mapper.new(SOLR_PEOPLEMAPPING).map(record)
  end

  # Remove a single record from Solr, both delete and commit are required
  def self.remove_from_solr(record)
    
    # not working ??
    if record.is_a?(String)
    #  IndexAtomicUpdates.delete_doc("{'delete':{'id':'#{record}'}}", 'people')
      SOLRPEOPLECONN.delete(record) 
    else
    #  IndexAtomicUpdates.delete_doc("{'delete':'{'id':#{record.id}'}}", 'people')
      SOLRPEOPLECONN.delete(record.id)
    end
    
    PeopleIndex.optimize_index
  end


  def self.optimize_index
    SOLRPEOPLECONN.optimize
  end

  #Fetch all documents matching a particular query,
  # along with the facets.
  # adding rows for group show page. Default otherwise is 10 which is set in search method of application controller
  def self.fetch(query_string, filter, rows, rand = nil) 
    
    if filter.include?('last_name:*')
      filter.delete_if{|x| x.include?('last_name:*')} 
      query_string = filter.delete_at(0) # assumes first_name: is first
    end     
    
    query_params = {
        :query => query_string,
        :filter_queries => filter,
        #:query_type => 'alphapaging', # doesn't work, gem doesnt allow query_type in standard request
        :field_list => ['display_name','people_data','active','verified_works_count','group_id'],
        #:start => self.start(page, rows),
        #:sort => [{sort.to_s => order.to_sym}], 
        :rows => rows 
    }

    # rows only for people in a Groups Search
    query_params.delete(:rows) if rows.nil?
    
    unless rand.nil?
      arr = [ {"random_#{rand}" => :asc} ]
      query_params[:sort] = arr
    end
    
    begin
      
      q = SOLRPEOPLECONN.send(Solr::Request::Standard.new(query_params))
      
      docs = process_response(q)

    rescue Exception => e
      # If anything goes wrong (bad query terms for instance), we want to use the DismaxRequestHandler
      # which will help parse the "junk" from users' queries... and will return 0 results.
      
      # Dismax.new creates a qt=dismax, how to make it alphapaging query_type is the question
      #q = SOLRPEOPLECONN.send(Solr::Request::Dismax.new(query_params)) 

      raise e
    end

    return docs
  end

  #Retrieve Spelling Suggestions from Solr, based on query
  def self.get_spelling_suggestions(query)
    spelling_suggestions = SOLRPEOPLECONN.send(Solr::Request::Spellcheck.new(:query => query)).suggestions
    if spelling_suggestions == query
      spelling_suggestions = nil
    end

    return spelling_suggestions
  end

  # can use this to get to a record from ruby console
  # ix = PeopleIndex.fetch_by_solr_id('24')
  def self.fetch_by_solr_id(solr_id)
    SOLRPEOPLECONN.send(Solr::Request::Standard.new(:query => "id:#{solr_id}")).data["response"]["docs"]
  end

  # at group level, author statistics, first last and in-between
  # at individual level use person model first_last_author_stats
  # this returns CSV from SOLR based on group ID of 51 (although URL is local only) (and 8983 is not port)
  # http://localhost:8983/solr/people/select?fl=id,display_name,verified_works_count,author_stats,active&fq=group_id:51&q=*:*&wt=csv
  def self.group_author_statistics(gid)
    filter = 'active:true'
    fields = ['id,display_name,active,verified_works_count,author_stats']
    group = "group_id:#{gid}"
  
    query_params = {
        :query => group,
        :filter_queries => filter,
        :field_list => fields
    }
    
    q = SOLRPEOPLECONN.send(Solr::Request::Standard.new(query_params))
    docs = process_response(q)
  
    phash = Hash.new
    astats = {first: 0, last: 0, middle: 0}
    list = Array.new
    ttl = 0
    
    docs.each {|doc|
      next if doc['verified_works_count'].to_i == 0
      next unless doc.key?('author_stats')
      
      auth = doc['display_name']
      pid = doc['id']
      ttl += doc['verified_works_count'].to_i 
      fa,la,ma = doc['author_stats'].split(',').collect{|x| x.to_i}
      astats[:first] += fa
      astats[:last] += la
      astats[:middle] += ma
      list << "#{auth} [#{pid}] first_author=#{fa}, last_author=#{la}"
    }
    
    p "total works produced for group: #{gid}: #{ttl}"
    p "first authors: #{astats[:first]}"
    p "last authors: #{astats[:last]}"
    p "otherwise: #{astats[:middle]}"
    
    p "==========="
    
    list.each{|perp| p perp}
  end
  
  ##
  ##
  #
  private

  #Process the response returned from a Solr query,
  def self.process_response(query_response)
    docs = query_response.data["response"]["docs"]
  end

end
