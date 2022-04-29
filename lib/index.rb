# encoding: UTF-8

require 'solr'
require 'active_support/core_ext/hash/indifferent_access'

class Index

  #### Solr ####

  # CONNECT
  # SOLRCONN = Solr::Connection.new("http://127.0.0.1:8983/solr/works")
  # calling from rails console
  # <Solr::Connection:0x007ff92ca87870 
  # @url=#<URI::HTTP http://127.0.0.1:8983/solr/works>, @autocommit=false, @connection=#<Net::HTTP 127.0.0.1:8983 open=false>>
  
  # SOLRCONN lives in initializers

  # SEARCH
  # q = solr.query("complex", :facets => {:zeros => false, :fields => [:author_facet]})
  # q = solr.query("comp*", {:field_list => ["author_facet"]})
  # q = solr.query("comp*", {:filter_queries => ["type_s:JournalArticle"]})

  # VIEW FACETS
  # @author_facets = @q.field_facets("name_string_facet")

  # DELETE INDEX - Very long process
  # @TODO: Learn how to use Solr "replication"
  ## works.each{|c| Index.remove_from_solr(c)}
  
  # NEW FIELDLIST with SOLR 6.3
  # using this in Typhoeus updates but may not be necessary now
  SOLR_FIELDLIST = %w{pk_i id _version_ orcid_id title title_secondary title_tertiary abstract sort_title issue volume type start_page status 
    issn_isbn publication publication_id publication_data publisher publisher_id publisher_data year name_strings name_string_id authors authors_data editors_data people people_data first_author_editor_sortkey 
     groups groups_data keywords type_facet year_facet name_string_facet person_facet title_lcsort title_dupe_key person_id research_focus  
    group_facet publication_facet publisher_facet keyword_facet name_string_dupe_key keyword_id name_strings_data group_id person_active yearmonth_range}
  

  # Default Solr Mapping
  SOLR_MAPPING = {
      # Work
      :pk_i => :id, #store Work ID as pk_i in Solr
      :id => Proc.new { |record| record.solr_id }, #create a unique Solr ID for Work
      :orcid_id => :orcid_id,
      :title => :title_primary,
      :title_secondary => Proc.new { |record| record.title_secondary.blank? ? nil : string_normalize(record.title_secondary) },
      :title_tertiary => Proc.new { |record| record.title_tertiary.blank? ? nil : string_normalize(record.title_tertiary) },
      :sort_title => :sort_name,
      :issue => :issue,
      :volume => :volume,
      :start_page => :start_page,
      :abstract => Proc.new { |record| record.abstract.blank? ? nil : string_normalize(record.abstract) },
         
      :status => :work_state_id,
      :issn_isbn => Proc.new { |record| record.publication.blank? ? nil : record.publication.issn_isbn },

      # Work Type (index as "Journal article" rather than "JournalArticle")
      :type => Proc.new { |record| record[:type].underscore.humanize },

      # NameStrings
      :name_strings => Proc.new { |record| record.name_strings.collect { |ns| string_normalize(ns.name.to_s) } },
      :name_string_id => Proc.new { |record| record.name_strings.collect { |ns| ns.id } },
      :name_strings_data => Proc.new { |record| record.name_strings.collect { |ns| ns.to_solr_data } },

      # MSK
      # moving first_author into a string field with docValues for SOLR 6.2 and keeping diacritic chars for sorting
      :first_author_editor_sortkey => Proc.new{|record| record.first_author_editor_sortkey},
      :source_facet => Proc.new{|record| record.source_facetkey},
      # also a title_lcsort => :title_primary in solr via copyField on title
      # changing this for SOLR 6.2, now a string field with docValues = true 
      #:title_lcsort => Proc.new{|record| record.title_lc_sort},

      # WorkNameStrings
      :authors_data => Proc.new { |record| record.authors.collect { |au| "#{string_normalize(au[:name])}||#{au[:id]}" } },
      :editors_data => Proc.new { |record| record.editors.collect { |ed| "#{string_normalize(ed[:name])}||#{ed[:id]}" } },
      #:contributors_data => Proc.new { |record| record.contributors.collect { |ed| "#{string_normalize(ed[:name])}||#{ed[:id]}" } },

      # People
      :people => Proc.new { |record| record.people.collect { |p| p.first_last } },
      :person_id => Proc.new { |record| record.people.collect { |p| p.id } },
      :people_data => Proc.new { |record| record.people.collect { |p| p.to_solr_data } },
      :research_focus => Proc.new {|record| record.people.collect {|p| p.research_focus.to_s.dump}},

      #Person's active status in separate field for filtering
      :person_active => Proc.new { |record| record.people.collect { |p| p.person_active.blank? ? false : p.person_active } },

      # Groups
      :groups => Proc.new { |record| record.people.collect { |p| p.groups.collect { |g| g.name } }.uniq.flatten },
      :group_id => Proc.new { |record| record.people.collect { |p| p.groups.collect { |g| g.id } }.uniq.flatten },
      :groups_data => Proc.new { |record| record.people.collect { |p| p.groups.collect { |g| g.to_solr_data } }.uniq.flatten },

      # Publication
      :publication => Proc.new { |record| record.publication.blank? ? nil : record.publication.name },
      :publication_id => Proc.new { |record| record.publication.blank? ? nil : record.publication.id },
      :publication_data => Proc.new { |record| record.publication.blank? ? nil : record.publication.to_solr_data },

      # Publisher
      :publisher => Proc.new { |record| record.publisher.blank? ? nil : record.publisher.name },
      :publisher_id => Proc.new { |record| record.publisher.blank? ? nil : record.publisher.id },
      :publisher_data => Proc.new { |record| record.publisher.blank? ? nil : record.publisher.to_solr_data },

      # Keywords
      :keywords => Proc.new { |record| record.keywords.collect { |k| string_normalize(k.name.to_s) } },
      :keyword_id => Proc.new { |record| record.keywords.collect { |k| k.id } },

      ## Tags commenting out NOV 2016
      #:tags => Proc.new { |record| record.tags.collect { |t| t.name } },
      #:tag_id => Proc.new { |record| record.tags.collect { |t| t.id } },

      # Duplication Keys
      :title_dupe_key => Proc.new { |record| record.title_dupe_key },
      :name_string_dupe_key => Proc.new { |record| record.name_string_dupe_key },

      # em identifier
      # not worrying about distinguishing between identifiers
      #:identifier => Proc.new{|record| record.identifiers.collect{|ids| ids.name }},
      
      # Timestamps
      :created_at => :created_at,
      :updated_at => :updated_at
  }

  # Mapping specific to dates
  #   Since dates are occasionally null they are only passed to Solr
  #   if the publication_date_year is *not* null.
  
  SOLR_DATE_MAPPING = SOLR_MAPPING.merge({
    :year => Proc.new { |record| record.publication_date_year }, 
    :year_facet => Proc.new { |record| record.publication_date_year },
    #:yearmonth_range => Proc.new { |record| record.publication_date_range }
  })
  # should I use this ??
  # after all SOLR is only getting the YEAR, so either may work
  #SOLR_DATE_MAPPING = SOLR_MAPPING.merge({:year => Proc.new { |record| record.publication_date.year }})  

  # Index all Works which have been flagged for batch indexing
  # NEW IN SOLR 6.3 argument for new_work_imports only set to true via calls from ProcessAcceptedImportJob > models/work 
  # and in Index.index_all (when rebuilding index)
  def self.batch_index(new_work_imports = false)
    
    Rails.logger.debug("\n============ NUMBEROFWORKSTOINDEX - #{Work.to_batch_index.length} ======\n")

    Work.to_batch_index.find_in_batches(batch_size: 50) do |records_slice|
      batch_update_solr(records_slice, new_work_imports) 
      records_slice.each{|x| x.mark_indexed }
    end

    # never I think, see solr_config.xml 
    #Index.optimize_index unless records.empty?
  end

  def self.start(page, rows)
    if page.to_i < 2
      0
    else
      (page.to_i - 1) * (rows.to_i)
    end
  end


  #Re-index *everything* in Solr
  #  This method is useful in case your Solr index
  #  gets out of sync with your DB
  def self.index_all
    #Delete all existing records in Solr
    SOLRCONN.delete_by_query('*:*')
    
    Work.find_in_batches(batch_size: 50) do |records_slice|
      batch_update_solr(records_slice, true) 
    end
    
    # CANNOT CALL COMMIT like this
    # WILL GET A waitFlush error as the call to the ruby gem using SOLRCONN uses the property waitFlush
    # prefer to do these every 
    #SOLRCONN.commit
    
    #Index.build_spelling_suggestions
  end
  
  # SHOULD NOT BE CALLING with upgrade to SOLR 6.x (more so because we're not using spelling)
  #def self.build_spelling_suggestions
  #  SOLRCONN.send(Solr::Request::Spellcheck.new(:command => "rebuild", :query => "physcs"))
  #end

  #Update a single record in Solr
  # (for bulk updating, use 'batch_update_solr', as it is faster)
  # changing commit to false for SOLR 6.x and changing semantics of second arg to distinguish new object vs. updated one
  def self.update_solr(record, commit_new_records = false)
    
    begin
      
      # due to the after callbacks which aren't really keyed well to after_save callbacks
      # can get here with a new work that does not yet have an id
      # will just silently be skipped

      unless Work.exists?(record.id)
        
        Rails.logger.info("\n\n ============ INDEX_UPDATINGS_SOLR with a new work, ID does NOT EXIST, NOT adding here")
        return true.to_s
        
      else
        
        unless commit_new_records
          
          # possible to get here with a work not in SOLR where new_record? or changed? will be false
          
          hsh = IndexAtomicUpdates.from_solr_get(record.id, 'Work')
          if hsh.key?(:no_results)
            
            emsg = hsh[:no_results]
          
            Rails.logger.info("\n\n ============ INDEX_UPDATINGS_SOLR: ADDING_AS_NEW_WORK - NO SOLR data results: #{record.id} ============\n")
            Rails.logger.info("============ ERROR_INDEX_REQUEST: #{emsg} ============\n") unless emsg.blank?
            
            # alert staff if record is saved and error generated in parsing (likely an Encoding error)
            record_staff_note(record.id, emsg) unless emsg.blank?
            
            # resetting 
            hsh = {} 
          end
            
          jsondoc = BibappSolrDataUpdate.new(record, hsh).compare
          
          result = ''
          # jsondoc would be empty if error 
          unless jsondoc.to_s.empty?
            Rails.logger.debug("\n\n ============ INDEX_UPDATINGS_SOLR: Index.update_solr UPDATE_EXISTING_WORK via PARTIAL ============\n")
            
            vsion = hsh.key?('_version_') ? hsh['_version_'] : ''
            result = IndexAtomicUpdates.update_doc(jsondoc, 'works', vsion)
            
            Rails.logger.debug("Returned from SOLR\n")
            Rails.logger.debug(result.inspect)
          else
            Rails.logger.debug("NO CHANGES to SOLR INDEX. Skipping ======= \n")
          end
          
          return result
            
          #end
        
        else
          raise RuntimeError, "Not expected to be here: in Index.update_solr with a new work"
        end
      end
      
    rescue Exception => e 

      Rails.logger.info("\n\n================INDEX_UPDATE_SOLR_EXCEPTION =============\n")
      Rails.logger.info(record.inspect)
      Rails.logger.info("\n-------------------\n")
      Rails.logger.info(e.to_s)
      
      # still let user know
      #raise e
      return e.to_s
      
    end
  end

  #Batch update several records with a single request to Solr
  #
  # NOTE: THIS MAY HAPPEN VIA A DELAYED JOB TASK and hence not available for a user to see the error
  #
  def self.batch_update_solr(records, index_new_records = false)

    Rails.logger.debug("\n\n================SOLR_DOC_INDEXING_BATCH_UPDATE using BibappSolrDataUpdate =============\n")
    Rails.logger.debug("Count of records: #{records.length}, Indexing as New Records: #{index_new_records}")

    if index_new_records
      
      # currently doing 50 at a time
      docs = Array.new
      records.collect do |record|
        hsh = IndexAtomicUpdates.from_solr_get(record.id, 'Work')
        hsh = {} if hsh.key?(:no_results)
        rc = BibappSolrDataUpdate.new(record, hsh).compare 
        docs << rc unless rc.blank? 
      end
      
      # not concerned with _version_ in update_doc call
      # options could be to set it to zero or not have it in the json (in both cases the document is added or overwritten)
      # can also pass versions=false in the query string to skip any response with version info passed back

      #Rails.logger.debug("\n======== Returned from BibappSolrDataUpdate and batch_update_solr\n")
      docs = docs.compact.flatten 
      unless docs.empty?
        result = IndexAtomicUpdates.update_doc(docs, 'works')
        Rails.logger.debug(result.inspect)
      else
        Rails.logger.debug("\n======== Nothing in this batch to update\n")
      end

    else
            
      records.each do |record|
        hsh = IndexAtomicUpdates.from_solr_get(record.id, 'Work')
        jsondoc = BibappSolrDataUpdate.new(record, hsh).compare
        result = ''
        # jsondoc would be empty if error 
        unless jsondoc.to_s.empty?
          Rails.logger.debug("\n\n ============ INDEX_UPDATINGS_SOLR: Index.update_solr UPDATE_EXISTING_WORK via PARTIAL ============\n")
          
          if hsh.key?('_version_')
            result = IndexAtomicUpdates.update_doc(jsondoc, 'works', hsh['_version_'])
          else
            result = IndexAtomicUpdates.update_doc(jsondoc, 'works')
          end
          
          Rails.logger.debug("Returned from SOLR\n")
          Rails.logger.debug(result.inspect)
          
          # seems otherwise staff get the result hash stringified as a flash message
          if result.key?("responseHeader") && result["responseHeader"].key?("status") && result["responseHeader"]["status"] == 0
            result = "Update successfull"
          end
          
        else
          Rails.logger.debug("NO CHANGES to SOLR INDEX. Skipping ======= \n")
        end        
      end
      
    end
  end

  # can run this from Console for testing, Index.solr_doc_from_record(w)
  def self.solr_doc_from_record(record)
    #if record.publication_date_year
    # since I've has changed this, what happens if only a year is passed
    # or does a year simply default to 1/1/year because that's what Mysql or Ruby does, given a date
    if record.publication_date_year
      #add dates to our mapping
      Solr::Importer::Mapper.new(SOLR_DATE_MAPPING).map(record)
    else
      Solr::Importer::Mapper.new(SOLR_MAPPING).map(record)
    end
  end

  # Remove a single record from Solr, both delete and commit are required
  # delete is idimpotent, no harm deleting what doesn't exist
  def self.remove_from_solr(record)
    # expecting work record or it's id as a string "Work-123456"
    
    # IndexAtomicUpdate not working sometimes get JsonLoader Can't have a value here. Unexpected STRING at [1] in SOLR debug output
    if record.is_a?(String)
      #IndexAtomicUpdates.delete_doc("{'delete':{'id':'#{record}'}}", 'works')
      SOLRCONN.delete(record)
    else
      #IndexAtomicUpdates.delete_doc("{'delete':'{'id':#{record.solr_id}'}}", 'works')
      SOLRCONN.delete(record.solr_id)
    end
  end

  # SHOULD NOT BE USING with 6.3 SOLR as it's expensive. Using mergeFactor setting should suffice
  def self.optimize_index
    SOLRCONN.optimize
  end

  #Fetch all documents matching a particular query,
  # along with the facets.
  def self.fetch(query_string, filter, sort, order, page, facet_count, rows)

    #Check array of filters to see if work 'status' specified
    filter_by_status = false
    filter.each do |f|
      if f.include?(Work.solr_status_field)
        filter_by_status = true
        break
      end
    end

    #If status unspecified, default to *only* showing "accepted" works
    filter.push(Work.solr_accepted_filter) if !filter_by_status
    
    #build our list of Solr query parameters
    # Note: the various '*_facet' and '*_facet_data' fields
    # are auto-generated by our Solr schema settings (see schema.xml)
    query_params = {
        :query => query_string.gsub(/[\(\)]/,''),
        :filter_queries => filter,
        :field_list => SOLR_FIELDLIST,
        :facets => {
            :fields => [
                :group_facet,
                :group_facet_data,
                :keyword_facet,
                :name_string_facet,
                :name_string_facet_data,
                :authors_data,
                :editors_data,
                :source_facet,
                :person_facet,
                :person_facet_data,
                :publication_facet,
                :publication_facet_data,
                :publisher_facet,
                :publisher_facet_data,
                :type_facet,
                :year_facet
                #{:year_facet => {:sort => :term}} even in original, doesn't harm but doesn't add anything either
                # as it adds to solr query f.year_facet.facet.sort=false in &fq=
            ],
            :mincount => 1,
            :limit => facet_count
        },
        :start => self.start(page, rows),
        :rows => rows
    }
    
    # MSK for multiple sort criteria unique to MSK
    if sort.class.to_s == 'Array' && order.class.to_s == 'Array'
      arr = Array.new
      sort.each_with_index {|k, i| 
        arr << {k => order[i].to_sym}
        }
    else
      arr = [{"#{sort}" => order.to_sym}]
    end
    query_params[:sort] = arr

    begin
      
      # First, try query with StandardRequestHandler
      q = SOLRCONN.send(Solr::Request::Standard.new(query_params))
      #q = SOLRCONN.send(Solr::Request::Select.new(query_params))

      # Rerun our search if the StandardRequestHandler came up empty...
      if q.data["response"]["docs"].size < 1
        # Try it instead with DismaxRequestHandler, which is more forgiving
        q = SOLRCONN.send(Solr::Request::Dismax.new(query_params))
      end

      # Processing returned docs and extract facets
      docs, facets = process_response(q)

    rescue
      # If anything goes wrong (bad query terms for instance), we want to use the DismaxRequestHandler
      # which will help parse the "junk" from users' queries... and will return 0 results.
      q = SOLRCONN.send(Solr::Request::Dismax.new(query_params))

      # Processing returned docs and extract facets
      docs, facets = process_response(q)
    end

    # return query response, docs and facets
    return q, docs, facets
  end

  #Retrieve Spelling Suggestions from Solr, based on query
  # NOT USING with SOLR 6.2
  #def self.get_spelling_suggestions(query)
  #  spelling_suggestions = SOLRCONN.send(Solr::Request::Spellcheck.new(:query => query)).suggestions
  #  if spelling_suggestions == query
  #    spelling_suggestions = nil
  #  end
  #
  #  return spelling_suggestions
  #end

  # can use this to get to a record from ruby console
  # ix = Index.fetch_by_solr_id('Work-124')
  def self.fetch_by_solr_id(solr_id)
    SOLRCONN.send(Solr::Request::Standard.new(:query => "id:#{solr_id}")).data["response"]["docs"]
  end

  # Retrieve recommendations from Solr, based on current Work
  def self.recommendations(work)
    
    # ISSUE WITH SOLR 6.2.1 is need explicit field list and field_list below is embedded in mlt
    # adding field_list but not sure that the MLT MoreLikeThisHandler will be engaged

    #Send a "more like this" query to Solr
    r = SOLRCONN.send(Solr::Request::Standard.new(
                          :query => "id:#{work.solr_id}",
                          :mlt => {
                              :count => 5,
                              :field_list => ["abstract", "title"]
                          },
                          :field_list => ["pk_i", "score"]
                          )
    )

    docs = Array.new

    #Add related docs to an array, if any like this one were found
    # adding Work.exists?
    # some works may no longer exist if index gets out-of-sync (happened with multi-delete from duplicates page)
    unless r.data["moreLikeThis"].empty? or r.data["moreLikeThis"]["#{work.solr_id}"].empty?
      r.data["moreLikeThis"]["#{work.solr_id}"]["docs"].each do |doc|
        next unless Work.exists?(doc["pk_i"]) 
        work = Work.find(doc["pk_i"])
        docs << [work, doc['score']]
      end
    end

    return docs
  end


  # Retrieve possible *accepted* duplicates from Solr, based on current Work
  #   Returns list of document hashes from Solr
  #  Note: if the work itself has been accepted, it will appear in this list
  def self.possible_accepted_duplicates(record)
    work = Hash.new
    #If this is a Work, generate dupe keys dynamically
    if record.kind_of?(Work)
      work['title_dupe_key'] = record.title_dupe_key
      work['name_string_dupe_key'] = record.name_string_dupe_key
    else #otherwise, this is data from Solr, so we already have dupe keys
      work = record
    end

    # Find all 'accepted' works with a matching Title Dupe Key or matching NameString Dupe Key
    query_params = {
        :query => "(title_dupe_key:\"#{work['title_dupe_key']}\" OR name_string_dupe_key:\"#{work['name_string_dupe_key']}\") AND #{Work.solr_accepted_filter}",
        :field_list => SOLR_FIELDLIST,
        :rows => 3
    }
    
    #Send a "more like this" query to Solr
    r = SOLRCONN.send(Solr::Request::Standard.new(query_params))

    #get the documents returned by Solr query
    docs = r.data["response"]["docs"]

    return docs
  end

  # Retrieve possible *accepted* duplicates from Solr, based on current Work
  #  Returns a list of Work objects
  #  Note: if the work itself has been accepted, it will appear in this list
  def self.possible_accepted_duplicate_works(work)
    dupes = Array.new

    # Query Solr for all possible duplicates
    #  This returns a hash of document information from Solr
    docs = possible_accepted_duplicates(work)

    #Get the Work corresponding to each doc returned by Solr
    docs.each do |doc|
      dupes << Work.find(doc["pk_i"]) rescue nil
    end
    return dupes.compact
  end

  # Retrieve all possible *unaccepted* duplicates from Solr, based
  # on current Work, and including the current Work itself
  #  Returns a list of Work objects
  #  Note: if the work itself has not been accepted, it will appear in this list
  def self.possible_unaccepted_duplicate_works(work)

    # Find all works with a matching Title Dupe Key or matching NameString Dupe Key
    query_params = {
        :query => "(title_dupe_key:\"#{work.title_dupe_key}\" OR name_string_dupe_key:\"#{work.name_string_dupe_key}\") AND (#{Work.solr_duplicate_filter})",
        :field_list => SOLR_FIELDLIST,
        :rows => 3
    }

    #Send a "more like this" query to Solr
    r = SOLRCONN.send(Solr::Request::Standard.new(query_params))

    #get the documents returned by Solr query
    docs = r.data["response"]["docs"]

    #Get the Work corresponding to each doc returned by Solr
    return docs.collect { |doc| Work.find(doc["pk_i"]) }
  end
  
  # Output a Work as if it came directly from Solr index
  # This is useful if a View has the full Work object
  # but still wants to take advantage of the
  # '/views/shared/work' partial (which expects the
  # work data to be in the Hash format Solr returns).
  def self.work_to_solr_hash(work)
    # Transform Work using our Solr Mapping
    if work.publication_date != nil
      #add dates to our mapping
      mapping = SOLR_MAPPING.merge(SOLR_DATE_MAPPING)
      doc = Solr::Importer::Mapper.new(mapping).map(work)
    else
      doc = Solr::Importer::Mapper.new(SOLR_MAPPING).map(work)
    end
    
    # We now have a hash with symbols (e.g. :title) for keys.
    # However, we need one with strings (e.g. "title") for keys.
    # So, we use HashWithIndifferentAccess to convert to a 
    # hash which has strings for keys.
    #solr_hash = HashWithIndifferentAccess.new(doc).to_hash
    solr_hash = ActiveSupport::HashWithIndifferentAccess.new(doc).to_hash
    
    return solr_hash
  end
  

  private

  #Process the response returned from a Solr query,
  # and extract out the documents & facets
  def self.process_response(query_response)

    #get the documents returned by Solr query
    docs = query_response.data["response"]["docs"]

    # Extract our facets from the query response.
    #  These come back as arrays of Solr::Response::Standard::FacetValue
    #  objects (e.g.) {:name="Sage Publications", 'value'=20}
    #  Note: the various '*_facet' and '*_facet_data' fields
    #  are auto-generated by our Solr schema settings (see schema.xml)
    facets = {
        :people => query_response.field_facets("person_facet"),
        :people_data => query_response.field_facets("person_facet_data"),
        :groups => query_response.field_facets("group_facet"),
        :groups_data => query_response.field_facets("group_facet_data"),
        :names => query_response.field_facets("name_string_facet"),
        :names_data => query_response.field_facets("name_string_facet_data"),
        :authors_data => query_response.field_facets("authors_data"),
        :editors_data => query_response.field_facets("editors_data"),
        :publications => query_response.field_facets("publication_facet"),
        :publications_data => query_response.field_facets("publication_facet_data"),
        :publishers => query_response.field_facets("publisher_facet"),
        :publishers_data => query_response.field_facets("publisher_facet_data"),
        :keywords => query_response.field_facets("keyword_facet"),
        #:tags => query_response.field_facets("tag_facet"),
        :types => query_response.field_facets("type_facet"),
        :years => query_response.field_facets("year_facet"),
        :sources => query_response.field_facets("source_facet") # msk
    }

    return docs, facets
  end
  
  # not sure that adding unicode_normalize is at all helpful
  # https://wiki.qt.io/Basics_of_String_Encoding and using NFKD just to see if composition into 2 chars does anything
  #
  def self.string_normalize(str)
    #Rails.logger.debug("\n======= NORMALIZING: #{str}")
    return str.force_encoding('UTF-8').encode('UTF-8').unicode_normalize(:nfkd)
  end
  
  def self.record_staff_note(wid, msg)
    if StaffWorkNote.exists?(:work_id => wid)
      swn = StaffWorkNote.find_by_work_id(wid)
      unless swn.note.include?('(IndexAtomicUpdates)')
        swn.note = swn.note.concat(" #{msg}")
        swn.save
      end
    else
      swn = StaffWorkNote.new
      swn.note = msg
      swn.work_id = wid
      swn.save
    end
  end

end
