# encoding: UTF-8
require 'json'

# HASHDIFF documentation here
# https://github.com/liufengyun/hashdiff


# replacing lib/index_solr_json to incorporate with bibapp_solr_data_update

class BibappSolrJsonDoc 
  
  attr_reader :doc, :updates, :scalar_keys, :mulitvalue_keys
  
  def initialize(type, id, updates = {}, scalar, multiv)
    @doc = Array.new
    @doc.push({'id' => set_id(type, id)} )
    @mapping = {'+' => 'add', '-' => 'remove', '~' => 'set'}
    @updates = updates
    @scalar_keys = scalar
    @multivalue_keys = multiv
  end
  
  # scalar values should never be 'add' THEY SHOULD BE SET only
  # and the HashDiff may be inadvertantly setting the wrong semantic for update
  # nonscalar array may have multiple values for a single key, eg name_strings[0] and name_strings[1] 
  # which need to be removed. If a array key is here, pull from Work record
  def map_non_scalar_values(darr)
    positions = Array.new
    as_scalar = Array.new
    darr.map.with_index do |arr, pos| 
      if @scalar_keys.include?(arr[1])
        darr[pos][0] = '~' if arr[0] == '+' 
      else
        field = arr[1].gsub(/\[.\d*\]/,'')
        if @multivalue_keys.index(field)
          as_scalar << ["~", field, @updates[field.to_sym]] if as_scalar.collect{|x| x[1]}.include?(field) == false
          positions << pos
        else
          # is this a problem?? probably
          Rails.logger.info("Missing NON-SCALAR KEY in bibapp_solr_json_doc: #{arr.inspect} | #{@doc.inspect}") 
          raise StandardError.new("Missing NON-SCALAR KEY in bibapp_solr_json_doc: #{arr.inspect}") 
        end
      end
    end
  
    positions.sort.reverse.each {|el| darr.delete_at(el) }
    as_scalar.each{|x| darr << x }
    return darr
  end
    
  def map_field_value(key, arr)
    # some keys have array index position in name
    # this removes but may need to replace the entire field in solr if position has changed
    # TODO, try re-arranging Authors 
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
      Rails.logger.info("SHOULD NOT BE HERE with #{key} : #{arr.inspect} | #{@doc.inspect}") 
      raise StandardError.new("SHOULD NOT BE HERE with #{key} :#{arr.inspect}") 
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
        @doc[pos] = nil if x.values.first.values.first.empty?
        #@doc[pos] = {x.keys.first => {"set"=>nil}} if x.values.first.values.first.empty?
        
      # SOLR will remove from index empty values, but it needs to be null  
      elsif x.values.first.values.first.is_a?(String)
        if x.values.first.values.first.empty?
          #@doc[pos] = {x.keys.first => {"set"=>nil}}
          @doc[pos] = nil
        end
      end
    }.compact!
  end
  
  def map(data)
    map_non_scalar_values(data).each {|arr|
      key = @mapping[arr.shift] # changing array !
      # as id was set in initialization and id would not be a changed attribute
      @doc.push(map_field_value(key, arr)) unless arr.first == 'id' 
    }
    
    # why set to nil if already empty
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