# encoding: UTF-8
#
# RIS format parser
# 
# Parses a valid RIS text file into a Ruby Hash.
# 
# All String parsing is done using String.mb_chars
# to ensure Unicode strings are parsed properly.
# See: http://api.rubyonrails.org/classes/ActiveSupport/CoreExtensions/String/Unicode.html
#
class RisParser < CitationParser
  
  def logger
    CitationParser.logger
  end
  
  #Determine if given data is RIS,
  # and if so, parse it!
  def parse_data(risdata)
    risdata = risdata.strip.gsub("\r", "\n")
    
    #determine if this is RIS data or not (looking for the 'ER' field)
    unless risdata =~ /^ER  \-/
      return nil
    end
    logger.info("\n\n* This file is RIS format.")
    
    #Individual records are separated by 'ER' field
    records = risdata.split(/^ER\s.*/i)
    if (risdata =~ /^ER\s{2}\-/) 
      if (risdata =~ /^XT\s{2}\-\sEndNote/)
        logger.debug("RIS parser says this file is RIS but also EndNote")
        return nil
      end
    end
    logger.debug("\n\n* This file is RIS format.")
    
    records.each_with_index do |rec, i|
      errorCheck = 1
      rec = rec.strip
      cite = ParsedCitation.new(:ris)

      # Save original data for inclusion in final hash
      cite.properties[:original_data] = rec

      # Use a lookahead -- if the regex consumes characters, split() will
      # filter them out.
      # Keys (or 'tags') are specified by the following regex.
      # See spec at http://www.refman.com/support/risformat_fields_01.asp
        
      logger.info("\nParsing...")
      
      rec.split(/(?=^[A-Z][A-Z0-9]\s{2}\-\s+)/).each do |component|
        # Limit here in case we have a legit " - " in the string
        key, val = component.split(/\s+\-\s+/, 2)
        
        # don't call to_sym on empty string!
        key = key.downcase.strip.to_sym if !key.downcase.strip.empty?
        
        # Skip components we can't parse
        next unless key and val
        errorCheck = 0
        
        # Add all values as an Array
        cite.properties[key] = Array.new if cite.properties[key].nil?
        cite.properties[key] << val.strip
      end

      # The following error should only occur if no part of the citation
      # is consistent with the RIS format. 
      if errorCheck == 1
        logger.error("\n There was an error on the following citation:\n #{rec}\n\n")
      else
        @citations << cite
      end
    end
  
    @citations
  end  
end