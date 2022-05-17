# Index Observer:
#   Performs Solr re-indexing for BibApp using Index model and PeopleIndex
class IndexObserver < ActiveRecord::Observer

  cattr_accessor :skip

  # Observe all models related to indexed Work information
  observe Work, Person, Group, Publication, Publisher, Attachment, Membership

  def after_save(record)
    return if self.class.skip
    if record.try(:require_reindex?)
      record.reindex_after_save
    end
  end

  def before_destroy(record)
    
    Rails.logger.debug("IN INDEX_OBSERVER_METHOD_BEFORE_DESTORY with #{record.id} AND #{record.class.to_s}")
    record.try(:reindex_before_destroy)
    
  end

end
