# modifying solr-ruby gem for encoding issues Aug 2019
Solr::Connection.class_eval do
  def send(request)
    data = post(request)
    data.force_encoding('UTF-8')
    Solr::Response::Base.make_response(request, data)
  end
end