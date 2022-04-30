# encoding: UTF-8
#this helper is for views in the shared folder
#since we don't know from whence they are called this is included into all views by ApplicationController -
#nevertheless, I want the separation from the methods in ApplicationHelper - these are really specific to
#the shared views, not all views
module SharedHelper
  include TranslationsHelper

  def letter_link_for(letters, letter, current, path)
    li_opts = (current == true) ? {:class => "current"} : {}
    link = path ? "#{path[:path]}?page=#{letter}" : {:page => letter}
    content_tag(:li, (letters.index(letter) ? link_to(letter, link, :class => "some") : content_tag(:a, letter, :class => 'none')), li_opts)
  end

  def link_to_authors(work)
    name_string_links(work['authors_data'], '', '', work['pk_i'])
  end

  def link_to_editors(work)
    name_string_links(work['editors_data'], work['authors_data'] ? (t('common.shared.in') + ' ') : '',
                      " (#{t 'common.shared.eds'})", work['pk_i'])
  end

  def name_string_links(name_string_data, prefix, postfix, work_id)
    return '' if name_string_data.blank?
    links = name_string_data.first(10).collect do |datum|
      name, id = NameString.parse_solr_data(datum)
      link_to(h("#{name.gsub(",", ", ")}"), name_string_path(id), {:class => "name_string"})
    end
    if name_string_data.size > 10
      links << link_to(t('common.shared.more'), work_path(work_id))
    end
    return [prefix, links.join("; "), postfix].join.force_encoding('UTF-8').encode('UTF-8').html_safe
  end

  def link_to_work_publication(work)
    link_to_work_pub_common(work['publication_data'], Publication, :publication_path)
  end

  def link_to_work_publisher(work)
    link_to_work_pub_common(work['publisher_data'], Publisher, :publisher_path)
  end

  def link_to_work_pub_common(pub_data, klass, path_helper_name)
    return t('app.unknown') if pub_data.blank?
    name, id = klass.parse_solr_data(pub_data)
    link_to("#{name_or_unknown(name)}", self.send(path_helper_name, id), {:class => "source"})
  end

  def add_filter(params, facet, value, count, label = nil)
    params = safe_hash(params.clone)
    label ||= value
    filter = Hash.new
    if params[:fq] && params[:fq].respond_to?(:collect)
      filter[:fq] = params[:fq].collect.to_a
    else
      filter[:fq] = []
    end

    filter[:fq] << "#{facet}:\"#{value.force_encoding('UTF-8').encode('UTF-8')}\""
    filter[:fq].uniq!

    link_to "#{label} (#{count})", params.merge(filter)
  end

  # have gotten empty strings instead of an array, not sure if that's an underlying bug
  def remove_filter(params, facet)
    params = safe_hash(params.clone)
    return unless params[:fq].respond_to?(:collect)
    filter = Hash.new
    if params[:fq] 
      filter[:fq] = params[:fq].collect.to_a
      filter[:fq].delete(facet)
      filter[:fq].uniq!
      #Split filter into field name and display value (they are separated by a colon)
      field_name, display_value = facet.split(':')
    end

    link_to "#{display_value}", params.merge(filter)
  end

  def add_daterange_filter(arr, params)
    arr = (Array.wrap('yearmonth_filter') + arr).compact if params.key?(:drq)
    return arr.blank? ? [] : arr
  end

  def link_daterange_filter(params)
    params = safe_hash(params.clone)

    if params[:drq]
      mt = params[:drq].match(/\[(.*)\sTO\s(.*)\]$/)
      if mt.length == 3
        sdate, edate = mt[1..2]
        y,m = sdate.split('-')
        disp = "#{m}/#{y}"
        y,m = edate.split('-')
        disp = "#{disp} to #{m}/#{y}"
      end
      # remove from query string
      params.delete(:drq)

      # add all facet criteria in play
      filter = Hash.new
      if params[:fq] && params[:fq].respond_to?(:collect)
        filter[:fq] = params[:fq].collect.to_a
      else
        filter[:fq] = []
      end
      filter[:fq].uniq!
  
      link_to "\"#{disp}\"", params.merge(filter)
    end

  end

  def facet_remove_filter(filter, object = nil)
    filter.clone.tap do |remove_filter|
      # Delete any filters pertaining to current object from removal list
      # Delete any filters pertaining to Work status (as different statuses are currently never shown intermixed)
      # Delete any filters pertaining to Person's active status (since we only want to see active people)
      # or filter pertaining to person_id:*, or year:. A filter that includes only vetted, authenticated authors - USED By MSK's hidden group
      remove_filter.delete_if do |f|
        (object and f.include?(object.solr_filter)) or
            f.include?(Work.solr_status_field) or
            f.include?("person_active:") or
            f.include?("person_id:*") or
            f.include?("year:")
      end
    end
  end

  def keyword_filter(keyword, object)
    filter = [%Q(keyword_facet:"#{keyword.name}")]
    filter << %Q(#{object.class.to_s.downcase}_facet:"#{object.name}") if object
    filter
  end

  #Take the list of facets of person data
  #skip those that we don't want to show, convert those we do want to show to a hash, end if we reach a maximum number
  def convert_and_filter_people_facets(facets, max_count, group, check_group, search_bypass = false)
    if facets.key?(:random_activepersons)
      pindex = true
      person_facets = facets[:random_activepersons] ||= [] # an array of hash
    else
      pindex = false
      person_facets = facets[:people_data] ||= [] # an array of Solr::Response::Standard::FacetValue
    end

    person_facets = person_facets.shuffle if pindex
    acc = Array.new
    idarr = Array.new
    counter = 0
    person_facets.each do |facet|
      pdata = pindex == true ? facet['people_data'] : facet.name 
      last_name, id, image_url, group_ids, size, active = Person.parse_solr_data(pdata)
      # the active flag is not kept up-to-date, but may be relevant for retrospective past years ingested from 2015 on
      unless search_bypass
        next if active.blank? or active == 'false'
        perp = Person.where(id: id)
        next if perp.blank?
        next if perp[0].active == false
      end
      break if max_count and counter >= max_count
      next if check_group and group_ids.exclude?(group.id)
      next if (image_url.blank? || image_url.to_s == 'man.jpg') && search_bypass == false
      next if idarr.include?(id)
      counter += 1
      acc << {:last_name => last_name, :id => id, :image_url => image_url}
      idarr << id
    end
    return acc
  end
  
  def work_action_link(link_type, solr_work, return_path = nil, saved = nil)
    work_id = solr_work['pk_i']
    case link_type
      when :find_it
        link_to_findit(solr_work)
      when :saved        
        #if saved and saved.items and saved.items.include?(work_id.to_i)
        if saved && saved.all_work_ids.include?(work_id.to_i)
          content_tag(:strong, "#{t 'app.saved'} - ") +
              link_to(t('app.remove'), remove_from_saved_work_url(work_id))
        else
          link_to t('app.save'), add_to_saved_work_url(work_id)
        end
      when :edit
        link_to t('app.edit'), edit_work_path(work_id, :return_path => return_path)
      else
        nil
    end
  end

  def alpha_pagination_items(include_numbers = false)
    items = ('A'..'Z').to_a
    items = ('0'..'9').to_a + items if include_numbers
    return items
  end

  def subclass_partial_for(work)
    file_name = "shared/work_subclasses/_#{work['type'].downcase.gsub(" ", "_")}".concat('.html.haml')
    rendered_name = "shared/work_subclasses/#{work['type'].downcase.gsub(" ", "_")}"
    File.exists?(File.join(Rails.root, 'app', 'views', file_name)) ? rendered_name : 'shared/work_subclasses/generic'
  end
  
  # msk
  def author_img_geometry(image_url, last_name, id, size, format)
    size = set_image_geometry(size, format)
    return link_to(image_tag(image_url, :class => "person-image", 
      :size => size, :alt => last_name, :title => last_name), person_path(id))
  end
  
  # combining Export to EndNote | PubMed PMID (e.g adding PubMed PMID)
  # this was copied from works_helper, USE IS DEPENDING ON WHERE Export to PubMed PMID is placed
  # in this helper it will on the same line as Results
  # called from shared/_works.html.haml
  def search_export_to_links(params)
    capture_haml :div, {style: 'display:inline;'} do 
      haml_concat "Export to "
      haml_concat search_ris_export("EndNote", params).html_safe
      haml_concat " | "
      haml_concat pmid_export("PubMed", params).html_safe
    end
  end
  
  def search_ris_export(label, params) 
    return "" if params[:total_hits].present? && params[:total_hits].to_s == '0'
    
    tparams = safe_hash(params.clone)
    ['publications', 'publishers'].each do |ctrl|
      if tparams['controller'].present? && tparams['controller'].include?(ctrl)
        field = ctrl.chop
        tparams["#{field}_id"] = params[:id]
      end
    end
    
    tparams.delete(:action)
    tparams.delete(:controller)
    tparams.delete(:commit)
    tparams.delete(:export) # having this will set up the CiteProc Export, don't want
    tparams.delete(:page) # initialize to 0, page will be set in call to search 
    if tparams[:fq].present? 
      tparams[:fq].delete_if{|f| f.include?('person_active')}
    end
    
    # might also want to remove sort from params, doesn't much matter in EndNote
    link_to label, "#{ris_export_path}?#{tparams.to_param}", :class => 'ris-export', :style => 'display:inline;'
  end
    
  # riffing off search_ris_export in shared_helper
  # this was copied from works_helper, USE IS DEPENDING ON WHERE Export to PubMed PMID is placed
  # in this helper it will on the same line as Results
  # called above
  def pmid_export(label, params) 
    return "" if params[:total_hits].present? && params[:total_hits].to_s == '0'
    
    tparams = safe_hash(params.clone)
    ['publications', 'publishers'].each do |ctrl|
      if tparams['controller'].present? && tparams['controller'].include?(ctrl)
        field = ctrl.chop
        tparams["#{field}_id"] = params[:id]
      end
    end
    
    tparams.delete(:action)
    tparams.delete(:controller)
    tparams.delete(:commit)
    tparams.delete(:export) # having this will set up the CiteProc Export, don't want
    tparams.delete(:page) # initialize to 0, page will be set in call to search 
    if tparams[:fq].present? 
      tparams[:fq].delete_if{|f| f.include?('person_active')}
    end
    
    # might also want to remove sort from params, doesn't much matter 
    link_to label, "#{pmid_export_path}?#{tparams.to_param}", :class => 'aexp-pmid', :style => 'display:inline;'
  end
  
  def isactive_ingroup(perp)

    enddate = Person.where(id: perp.id).pluck(:end_date).first
    if enddate.blank? 
      return (perp.works.count == 0) ? false : true
    else
      return false if enddate.is_a?(Date) == false
      return ((DateTime.now.year - enddate.year) > 1 ) ? false : true
    end
    
    # SOLR HAS A GROUP ASSOCIATED
    # ingrp,na,active = Person.find(perp.id).to_solr_data.split('||')[3..5]
    #if ingrp.empty? == false
    #  parr = Membership.where(person_id: perp.id).pluck(:id, :end_date)
    #  return parr.collect{|x| x[1]}.compact.length != parr.length
    #end
    # NO SOLR GROUP AFFILIATED WITH THIS PERSON
    #return false # ingrp.empty? == true
    
  end
  
  def safe_hash(prms)
    hsh = Hash.new
    prms.each {|x,v| hsh[x] = v}
    ActiveSupport::HashWithIndifferentAccess.new(hsh)
  end
  
  def fix_for_utf(data)
    arr = []
    data.each {|w|
      vals = w.split('||')
      str = "#{vals[0].force_encoding('UTF-8')}||#{vals[1]}"
      arr << str
    }
    arr
  end
  
  
end