# encoding: UTF-8
require 'json'

## THIS WAS REPLACED BY SynapseSolrJsonDoc for Jan 17, 2017 rollout

# HASHDIFF documentation here
# https://github.com/liufengyun/hashdiff

class SolrJsonDoc 
  
  attr_reader :doc, :updates, :scalar_keys
  
  def initialize(type, id, updates = {})
    @doc = Array.new
    @doc.push({'id' => set_id(type, id)} )
    @mapping = {'+' => 'add', '-' => 'remove', '~' => 'set'}
    @updates = updates
    @scalar_keys = ["pk_i","orcid_id","title","title_secondary","title_tertiary","sort_title","issue","volume","start_page","abstract","status","issn_isbn","publication","publisher","type","year","first_author_editor_sortkey","title_lcsort","publication_data","publisher_data","yearmonth_range"]
  end
  
  # scalar values should never be 'add' THEY SHOULD BE SET only
  # and the HashDiff may be inadvertantly setting the wrong semantic for update
  # nonscalar array may have multiple values for a single key, eg name_strings[0] and name_strings[1] 
  # which need to be removed. If a array key is here, pull from Work record
  def map_non_scalar_values(darr)
    positions = Array.new
    as_scalar = Array.new
    # adding name_string_id JAN 09
    arrvalues = ['keywords', 'authors_data', 'authors', 'editors_data', 'editors', 'name_strings', 'identifier', 'people_data', 'people', 'groups', 'person_id', 'name_string_id', 'research_focus', 'person_active', 'group_id']
    darr.map.with_index do |arr, pos| 
      # scalars should not be add, need to be set, which is an outcome of HashDiff
      darr[pos][0] = '~' if arr[0] == '+' && @scalar_keys.include?(arr[1])
    
      field = arrvalues.find{|fld| arr[1].start_with?(fld)}
      if field
        # need to pull the data from record 
        as_scalar << ["~", field, @updates[field.to_sym]] if as_scalar.collect{|x| x[1]}.include?(field) == false
        # and save location in array
        positions << pos
      end
    end
  
    # remove from source array
    positions.sort.reverse.each {|el| darr.delete_at(el) }
    # combine and return
    as_scalar.each{|x| darr << x }
    return darr
  end
    
  def map_field_value(key, arr)
    # some keys have array index position in name
    # this removes but may need to replace the entire field in solr if position has changed
    # TODO, try be re-arranging Authors 
    # so if need to replace will need to do a both a remove and add using entire structure
    fld = arr.first.gsub(/\[.\d*\]/,'')
    case key
    when 'add'
      {fld => {key => arr.last}}
    when 'set'
      #this is probably third, same as last
      {fld => {key => arr.last}}
    when 'remove'
      {fld => {key => arr.last}}
    else
      Rails.logger.info "SHOULD NOT BE HERE with #{key} :: #{arr.inspect}"
    end
  end
  
  # this would not be necessary if the HashDiff or corresponding code removed empty values
  # also set nil to empty string values
  def clean_up_doc
    # expecting all fields except the first to be a Hash as this is an update to existing
    # and class initialization sets first hash value to a String, not a Hash
    # the id would not be existant for a real object that is just being updated as the ID doesn't change
    
    @doc.each_with_index {|x, pos| 
      next unless x.values.first.is_a?(Hash)
      next unless x.values.first.values.is_a?(Array)
      if x.values.first.values.first.is_a?(Array)
        #@doc[pos] = nil if x.values.first.values.first.empty?
        @doc[pos] = {x.keys.first => {"set"=>nil}} if x.values.first.values.first.empty?
        
      # SOLR will remove from index empty values, but it needs to be null  
      elsif x.values.first.values.first.is_a?(String)
        if x.values.first.values.first.empty?
          @doc[pos] = {x.keys.first => {"set"=>nil}}
        end
      end
    }.compact!
  end
  
  def map(data)
    map_non_scalar_values(data).each {|arr|
      key = @mapping[arr.shift]
      # as id was set in initialization and id would not be a changed attribute
      @doc.push(map_field_value(key, arr)) unless arr.first == 'id' #or arr.first == '_version_'
    }
    
    clean_up_doc unless @doc.empty?
    
    # convert array of hashes into a json hash
    # careful with reduce and merge as any duplicate keys will be overwritten by last key
    unless @doc.collect{|k| k.keys}.flatten.uniq.length == @doc.length
      Rails.logger.info("\n\n ======== **** SOLR_HASH_KEY_DUPLICATION ***** ===========\n")
      @doc.each{|rec| Rails.logger.info(rec.inspect) }
    end
    
    to_hash = @doc.reduce(Hash.new, :merge)
    unless to_hash.keys.length == 1 
      return Array.wrap(to_hash)
    else
      # just id key in hash means nothing to update
      return ''
    end
    
  end
  
  
  # private
  #
  
  def set_id(type, id)
    id.include?("#{type}-") ? id : "#{type}-#{id}"
  end
  
end
