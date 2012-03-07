class PublicationsSweeper < AbstractSweeper
  observe Work, Publisher, Publication, Contributorship

  def after_save(record)
    expire_content(record)
  end

  def after_update(record)
    expire_content(record)
  end

  def after_destroy(record)
    expire_content(record)
  end

  protected

  def expire_content(record)
    ids = get_publication_ids(record)
    publications = (record.destroyed? and record.is_a?(Publication)) ? [record] : Publication.find(ids)
    #expire individual publication rows
    ids.each do |id|
      bibapp_expire_fragment_all_locales(:controller => 'publications', :action => 'index', :id => id, :action_suffix => 'publication-row')
    end
    #expire all relevant full index tables
    publications.collect { |p| p.sort_name.first.upcase }.compact.uniq.each do |page|
      bibapp_expire_fragment_all_locales(:controller => 'publications', :action => 'index', :page => page, :action_suffix => 'index-table')
    end
  end

  def get_publication_ids(record)
    case record
      when Work
        trigger_expiration?(record, :publication_id_changed?) ? [record.publication_id, record.publication_id_was].compact  : []
      when Publisher
        trigger_expiration?(record, :name_changed?, :romeo_color_changed?) ? record.publication_ids : []
      when Publication
        trigger_expiration?(record, :name_changed?, :issn_isbn_changed?) ? [record.id] : []
      when Contributorship
        trigger_expiration?(record, :contributorship_state_id_changed?) ? [record.work.publication_id] : []
    end
  end
end