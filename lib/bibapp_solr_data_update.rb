# encoding: UTF-8
require 'index'
require 'solr'
require 'typhoeus'
require 'yaml'
require 'json'

require 'bibapp_solr_json_doc'


class BibappSolrDataUpdate
  
  # SOLR FIELDS from index.rb via SOLR_MAPPING and any others in SOLR 7.1 schema
  ALL_FIELDLIST = [:pk_i, :id, :title, :title_secondary, :sort_title, :volume, :start_page, :abstract, :status, :issn_isbn, 
    :type, :publication, :publication_data, :publisher_data, :publisher, :publisher_id, :publication_id, 
    :title_dupe_key, :name_string_dupe_key, :year, :year_facet, :source_facet, :title_tertiary, :issue, :name_strings, 
    :name_strings_data, :authors_data, :editors_data, :keywords, :people, :people_data, :research_focus, :person_active, 
    :groups, :groups_data, :keyword_id, :person_id, :name_string_id, :group_id, :created_at, :updated_at, :_version_, :publisher_facet, 
    :name_string_facet, :person_facet, :type_facet, :publication_facet, :group_facet, :keyword_facet, :authors, :updated_at_sort, 
    :year_sort, :sort_title_sort, :title_sort, :group_facet_data, :name_string_facet_data, :person_facet_data, :publication_facet_data, 
    :publisher_facet_data]
  
  # as in multiValued field in SOLR schema
  MULTI_VALUED = [:keywords, :keyword_id, :authors_data, :authors, :editors_data, :editors, :name_strings, :people_data, :people, 
    :groups, :person_id, :research_focus, :person_active, :group_id, :name_string_id, :publication_id, :publisher_id, :name_strings_data,
    :groups_data]

  attr_reader :w, :s, :keys, :wclass, :dkeys, :diff

  def initialize(record, record_hsh = {})
    obj = record.class.ancestors
    @wclass = case 
    when obj.include?(Person)
      "Person"
    when obj.include?(Work)
      "Work"
    else
      "Unknown"
    end
    
    @keys = filter_keys
    
    # MAPPED FROM THE CURRENT edited WORK to SOLR keys
    # so work record becomes @w for comparison
    # and @s is solr data from /get handler
    @w = Index.solr_doc_from_record(record)
    
    @w.symbolize_keys! 
    @s = record_hsh.empty? ? {} : record_hsh.symbolize_keys 
    
    @dkeys = Hash.new
    @diff = Array.new
    
  end
  
  def keys
    @keys
  end
  
  def compare    
    
    #Rails.logger.debug("\n\n=========== SOLR_DATA_UPDATE COMPARE: ORIGINAL_HASH ==============\n")
    #@w.each{|k,v| Rails.logger.debug "#{k} = #{v}"}
    #@s.each{|k,v| Rails.logger.debug "#{k} = #{v}"}

    # remove fields not relevant
    @w.reject!{|k,v| @keys.include?(k) == false }
    @s.reject!{|k,v| @keys.include?(k) == false } unless @s.empty?

    
    # CREATE CONSISTENT DATA STRUCTURES
    as_integer # integers as strings
    as_array # not sure if sort will alter person_id or name_string_id because of ordering, but other keys shouldn't matter
    to_boolean(:person_active, @w) # for boolean values as strings 
    to_solr_date([:created_at, :updated_at], @w)
    distinct_groups_array # coming from multiple contributors of a work these can duplicate
    
    #Rails.logger.debug("\n\n=========== CLEANED_UP_HASH ==============\n")
    #@w.each{|k,v| Rails.logger.debug "#{k} = #{v}"}
    #@s.each{|k,v| Rails.logger.debug "#{k} = #{v}"}
    
    @diff = HashDiff.diff(@s, @w, {:strict => false} )
    @diff.each_with_index{|arr,pos| @dkeys[arr[1].to_sym] = pos}
    
    Rails.logger.debug("\n\n=========== WORK SOLR_DATA_DIFFERENCES ==============\n")
    @diff.each{|rc| Rails.logger.debug(rc)}
    
    updates = Array.new    
    @keys.each do |k|
      updates << case MULTI_VALUED.include?(k) 
        when true
          match_array_values(k)
        else
          match_string_value(k)
        end
    end
    
    updates.compact!
    unless updates.empty?
      scalar_keys = (@keys - MULTI_VALUED).collect{|x| x.to_s}
      mv_keys = MULTI_VALUED.collect{|x| x.to_s}
      mdoc = BibappSolrJsonDoc.new(@wclass, @w[:id], @w, scalar_keys, mv_keys).map(@diff)
      
      Rails.logger.debug("\n\n ============== WORK JSON_DOC_FOR_SOLR_ATOMIC_UPDATE #{@w[:id]}==================\n")
      Rails.logger.debug(mdoc)
    
      return mdoc
    else
      return ''
    end
    
  end
  
  #
  # 
  private
  
  def match_string_value(kf)
    matched = @w[kf] == @s[kf]
    matched == true ? nil : @diff[@dkeys[kf]]
  end
  
  # HashDiff works on individual array positions and will have multiple keys person[0] and person[1]
  # which aren't fields, in which case pulling from work record 
  def match_array_values(kf)
    matched = @w[kf] == @s[kf]
    return nil if matched == true
    @dkeys.key?(kf) == true ? @diff[@dkeys[kf]] : ['~', kf.to_s, @w[kf]]
  end

  def as_integer
    [@w, @s].each {|orecord|
      [:pk_i,:status,:person_id,:publication_id,:publisher_id,:keyword_id,:year,:name_string_id,:group_id].each{|ss| 
        next unless orecord.key?(ss)
        if orecord[ss].is_a?(Array)
    		  orecord[ss] = orecord[ss].collect{|x| x.to_i}.to_a if orecord[ss].join.gsub(/[\d*]/,'').empty?
        else
          orecord[ss] = orecord[ss].to_i if orecord[ss].to_s.gsub(/[\d*]/,'').empty?
        end
      }
    }
  end
  
  def as_array
    [:person_id,:publication_id,:publisher_id,:keyword_id,:name_string_id,:group_id].each{|vv| 
      if @w[vv] || @s[vv]
          [@w,@s].each {|obj| 
            next unless obj.key?(vv)
            val = obj[vv].is_a?(Array) ? obj[vv].collect{|x| x} : Array.wrap(obj[vv]).collect{|x| x}
            obj[vv] = val.sort
          }
      end
    }
  end

  # at the source only
  def distinct_groups_array
    [:groups, :group_id, :groups_data].each{|vv| 
      @w[vv].uniq! if @w.key?(vv)
    }
  end
  
  def to_boolean(fld, obj)
    if obj.key?(fld)
      obj[fld] = obj[fld].collect{|x| x == 'true'.to_s ? true : false} 
    end
  end
  
  # UTC format for solr, expecting a work hash in obj for date to UTC conversion
  def to_solr_date(arr, obj)
    arr.each {|fld|
      if obj.key?(fld)
        obj[fld] = obj[fld].to_s(:db).sub(/\s/,'T').concat('Z') 
      end
    }
  end
  
  def filter_keys
    dupekeys = ALL_FIELDLIST
    # think title_lcsort is no longer an entity
    # need status and pk_i. 
    # not sure how updated_at or updated_at_sort is being used, but keeping. updated_at doesn't appear in code
    # copy fields not for comparison 'authors, _facet_data as well 
    return dupekeys.delete_if { |x| 
      x.to_s.end_with?('_facet','_sort','_version_', 'title_lcsort', 'authors', '_facet_data') } + 
      [:source_facet, :updated_at_sort].flatten
  end
end
