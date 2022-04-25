# encoding: UTF-8
require 'index'
require 'solr'
require 'typhoeus'
require 'yaml'
require 'json'

require "solr_json_people_doc"

#require "#{File.expand_path(File.dirname(__FILE__))}/index_solr_json_people"


class BibappSolrPersonUpdate
  
  
  def self.update_person(record, record_hsh = {})
    begin      
      
      if record_hsh.empty?
        Rails.logger.debug " ========= PERSON RECORD_DOES_NOT_EXIST_IN_SOLR ============= "
        Rails.logger.debug " SHOULD NOT BE HERE ********* "
      end
      
      Rails.logger.debug "PERSON RECORD IS class: #{record.class}" 
      Rails.logger.debug "PERSON RECORD IS new: #{record.new_record?}" 
      #Rails.logger.debug "PERSON RECORD has direct attribute changes: #{record.changes.length > 0}" 
      Rails.logger.debug "PERSON RECORD has direct attribute changes: #{record.saved_changes.length > 0}" 
    
      # this check doesn't guarantee there were not associated changes
      # some fields arent stored in Work Table so will not be present IN THIS HASH
      if record.saved_changes.length > 0
        #record.changes.keys.each {|k|
        record.saved_changes.keys.each {|k|
          Rails.logger.debug "#{k} == #{record[k]}"
        } 
      end

      # MAPPED FROM THE CURRENT WORK, edits included suitable for SOLR
      # record becomes doc for comparison
      doc = PeopleIndex.solr_doc_from_record(record)
      
      doc.symbolize_keys!
      hsh = record_hsh.symbolize_keys unless record_hsh.empty?
    
      hshdeletes = [:created_at, :updated_at, :_version_]
      docdeletes = [:created_at, :updated_at]
      hsh = hsh.delete_if {|k,v| hshdeletes.include?(k)} 
      doc = doc.delete_if {|k,v| docdeletes.include?(k)} 
      
      # same functionality as a work (below)
      [:group_id].each{|ss| 
      	unless hsh.key?(ss).blank? 
          if hsh[ss].is_a?(Array)
      		  hsh[ss] = hsh[ss].collect{|x| x.to_i}.to_a if hsh[ss].join.gsub(/[\d*]/,'').empty?
          else
            hsh[ss] = hsh[ss].to_i if hsh[ss].gsub(/[\d*]/,'').empty?
          end
      	end
      }
      # group_id can show a different sort 
      if hsh[:group_id] && doc[:group_id]
        [doc,hsh].each {|obj| obj[:group_id] = obj[:group_id].collect{|x| x}.sort }
      end
      
      to_solr_date([:created_at], doc)
    
      # https://github.com/liufengyun/hashdiff
      # could reverse but hsh, doc seems workable and reverse does not
      diff = HashDiff.diff(hsh, doc, {:strict => false} )
    
      Rails.logger.debug("\n===== HASH_DIFF ===========\n")

      Rails.logger.debug("DIFF ARRAY")
      diff.each_with_index {|arr, pos| 
        Rails.logger.debug("#{pos} = #{arr.inspect}") 
      }
    
      keys_delete = Array.new
      diff.each_with_index {|arr, pos| 
        next unless arr[0] == '+'
        case arr[1]
        when 'machine_name'
          keys_delete << pos if record.machine_name == arr[2]
        #when 'group_id'
          #keys_delete << pos if record.groups == arr[2]
        end
      }
      keys_delete.reverse.each {|el| diff.delete_at(el) }
    
      keys_delete = []
      diff.each_with_index {|arr, pos| 
        next unless arr[0] == '~' # careful matching below against revised value arr[3]
        case arr[1]
        when 'id'
          keys_delete << pos if arr[2].to_s == arr[3].to_s
        when 'verified_works_count' 
          keys_delete << pos if arr[2].to_s == arr[3].to_s
        end
      }
      keys_delete.reverse.each {|el| diff.delete_at(el) }
      Rails.logger.debug("differences")
      diff.each { |arr|
        Rails.logger.debug(arr.inspect) 
      }

      unless diff.empty?
        mdoc = SolrJsonPeopleDoc.new(doc[:id], doc).map(diff)
        Rails.logger.debug("\n\n ============== JSON_PEOPLE_DOC_FOR_SOLR_ATOMIC_UPDATE ==================\n")
        Rails.logger.debug(mdoc)
    
        return mdoc
      else
        return ''
      end
    
    rescue Exception => e
      Rails.logger.info("\n ====== EXCEPTION_IN_INDEX_ATOMIC_UPDATES for PEOPLE #{doc[:id]} ==========")
      Rails.logger.info(e.to_s)
      return ''
    end
    
  end
 
  # UTC format for solr, expecting a work hash in obj for date to UTC conversion
  def self.to_solr_date(arr, obj)
    arr.each {|fld|
      if obj.key?(fld)
        obj[fld] = obj[fld].to_s(:db).sub(/\s/,'T').concat('Z') 
      end
    }
  end
  
end