# encoding: UTF-8

require 'index'
require 'solr'
require 'typhoeus'
require 'yaml'
require 'json'
#require 'active_support' # nec. for unicode_normalize only
require 'string_methods'

# new with SOLR 6.3 and using Atomic Updates 
# specific semantics for updating the Work related data comprised of
# work data
# publication and publisher data
# people data

# atomic updates can target updates to only those fields that have changed
# using add set remove (removeregex and inc)

# get will show updated/changed value immediately (not sure how softCommit factors into this, but it would presumably)
# my test example 
# http://127.0.0.1:8983/solr/works/get?id=Work-94192&wt=ruby


class IndexAtomicUpdates
  
  # not clear that explicit field list will help with SOLR error around RealTimeGet
  # or even why removing year_facet helps (though has in a browser test)
  # regardless of any error the update to SOLR happens, but not via atomic update
  SOLR_WORK_FLDS = (Index::SOLR_FIELDLIST - ['year_facet']).join(',')
    
  # http://127.0.0.1:8983/solr/people/get?id=14792&wt=json
  # http://127.0.0.1:8983/solr/works/get?id=Work-94478&wt=json
  
  def self.solr_connection
    SOLRCONN.url.to_s.split('/solr').first
  end
  
  # use Typhoeus
  def self.from_solr_get(id, type = 'Work')
    whash = Hash.new
    result = ''
    @emsg = ''
    
    wid = (type == 'Work') ? self.get_work_id(id) : id
    obj = (type == 'Work') ? 'works' : 'people'
    
    url = solr_connection 
    connection = "#{url}/solr/#{obj}/get"
    request = Typhoeus::Request.new(
      connection,
      method: :get,
      params: { id: wid, wt: 'json', indent: 'false', fl: SOLR_WORK_FLDS.dup },
      headers: { Accept: "application/json" }
    )
    
    request.options[:params].delete(:fl) unless type == 'Work'
    
    request.on_complete do |response|
      
      if response.success?
        response = request.response
        
        # thinking is
        # allow exceptions to pass as a failure will be skipping an update change to SOLR
        # but as staff edit the work the errors should be cleared and SOLR will be updated with changes
        begin
          Rails.logger.debug("\n======== YAML_LOADING: #{obj} #{wid}")
          
          #body = response.body.sub("\xEF\xBB\xBF".force_encoding("UTF-8"), '').encode("UTF-8")
          body = StringMethods.ensure_utf8(response.body)
          
          result = Psych.safe_load(body)
        
        # this is a bigger exception than just a parsing error
        #rescue Psych::SyntaxError => e
          # Rails.logger.info("YAML_PROCESS_ERROR == #{e.to_s}")
          #@emsg = "Yaml process error for: #{obj} #{wid}"
        
        # let this through and record in work note
        rescue Encoding::CompatibilityError => ec
          Rails.logger.info("EXCEPTION_PROCESSING_ERROR: #{obj} #{wid} == #{ec.to_s}")
          #@emsg = "Error (IndexAtomicUpdates): ASCII encoding issue found. "

        rescue Exception => ex
          #raise RuntimeError, "Exception parsing #{obj} #{wid} in IndexAtomicUpdates. #{ex.to_s}"
          Rails.logger.info("\n ======= Exception parsing #{obj} #{wid} in IndexAtomicUpdates. #{ex.to_s}")
          #@emsg = "Error (IndexAtomicUpdates): #{ex.to_s}"
        end
    
      elsif response.timed_out?
        @emsg = "(IndexAtomicUpdates) resonse timed out"
        p @emsg 
      elsif response.code == 0
        @emsg = "(IndexAtomicUpdates) response code == 0"
        p @emsg
      elsif response.code == 500
        @emsg = "(IndexAtomicUpdates) Server Response code: 500"
      else
        @emsg = "(IndexAtomicUpdates) Unexpected result: response code: #{response.code}"
        p @emsg
      end
    end

    # initiate the request
    request.run

    whash = result['doc'] if result.respond_to?(:keys) && result.key?('doc') && result['doc'].nil? == false
    return whash.empty? ? {:no_results => @emsg} : whash

  end
  
  
  # $ curl -X POST -H 'Content-Type: application/json' 'http://127.0.0.1:8983/solr/techproducts/update?_version_=999999&versions=true' --data-binary '
  # next works, it's wrapped in an array
  #echo -e "[{'id':'Work-94193', 'abstract':{'set':'Some stuff'}, 'title':{'set':'All things considered'}}]" | curl -X POST -H "Content-Type: text/json" -vvv --data-binary @- 'http://127.0.0.1:8983/solr/works/update'
  
  # same handler as update, but  { "delete":"myid" } or { "delete":"myid", "_version_":"123456" }
  def self.delete_doc(jsondoc, type)
    
    obj = (type == 'works') ? 'works' : 'people'
    url = solr_connection 
    connection = "#{url}/solr/#{obj}/update?commit=true"
    result = ''
    json = jsondoc.to_json
    
    request = Typhoeus::Request.new(
      connection,
      method: :post,
      body: json,
      params: {},
      headers: { "Content-Type" => "application/json" }
    )
    request.on_complete do |response|
      if response.success?
        response = request.response
        result = YAML::load(response.body)
      
      elsif response.timed_out?
        p "resonse timed out"
      elsif response.code == 0
        p "response code == 0"
      else
        Rails.logger.info("Delete error: #{response}")
      end
    end
  
    # initiate the request
    request.run
    
    return result
    
  end
  
  def self.update_doc(jsondoc, type, version = '')
    
    obj = (type == 'works') ? 'works' : 'people'
    url = solr_connection 
    connection = "#{url}/solr/#{obj}/update"
    result = ''
    json = jsondoc.to_json
    
    # commitWithin set to 5 seconds per document
    
    unless version.to_s.empty?
      request = Typhoeus::Request.new(
        connection,
        method: :post,
        body: json,
        params: { '_version_': version, versions: true, commitWithin: 5000 },
        headers: { "Content-Type" => "application/json" }
      )
    else
      request = Typhoeus::Request.new(
        connection,
        method: :post,
        body: json,
        params: { commitWithin: 5000 },
        headers: { "Content-Type" => "application/json" }
      )
    end
    
    request.on_complete do |response|
    
      if response.success?
        response = request.response
        result = YAML::load(response.body)
      
      elsif response.timed_out?
        p = "resonse timed out"
      elsif response.code == 0
        p = "response code == 0"
      else
        Rails.logger.info("Update error: #{response}")
      end
    end
  
    # initiate the request
    request.run
    
    return result
    
  end


  # 
  # private

  # assumes numeric value
  def self.get_work_id(id)
    return id.to_s.gsub(/[\d*]/,'').length == 0 ? "Work-#{id}" : id
  end
  
  # even with app/concerns/normalize_blank_values the empty vals are still coming
  def self.remove_empty_values(doc, diff)
    scalr = [:orcid_id,:title_secondary,:title_tertiary,:issue,:volume,:start_page,:abstract,:issn_isbn,:publication,:publisher,:publication_data,:publisher_data,:yearmonth_range]
    flds = Array.new
    doc.each {|k,v| flds << k if v.to_s.empty?}
    
    unless (scalr - flds).length == scalr.length
      (scalr - (scalr - flds)).each {|x| 
        Rails.logger.debug("EMPTY VALUE: need to set #{x.to_s} to NIL")
        diff << ['~', x.to_s, ''] # will be set to nil in SolrJsonDoc
      }
    end
    
    # above could create both a ~ and a + for the same key, 
    # only want the ~ since this is for removing 
    # but if it's empty remove it too, no need to update solr when the value is empty
    arr = Array.new 
    diff.each_with_index {|x,pos| 
      arr << pos if x.last.to_s.empty? && ['+','~'].include?(x.first) && flds.include?(x[1].to_sym)
    }.compact.uniq
    arr.reverse.each {|el| diff.delete_at(el) }
  end
  
  
end