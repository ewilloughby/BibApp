class ImportFile < Attachment
  # Inherits default settings from Attachment model
 
  # use a mime type
  #validates_attachment_content_type :data, :content_type => [/text\/plain/]
  
  # mime type has been wrongly attributed in a scopus file as: text/x-c++ because of keywords starting a line in the ris .txt file 
  # those keywords can be found on the server at /usr/share/misc/magic
  # might be able to override by putting the magic file in rubyapp home directory minus those keywords
  # but this fixes the problem too, unlikely staff would be uploading a harmful file
  #validates_attachment_content_type :data, :content_type => [/text\/xml/, /text\/x-c++/]
  #validates_attachment_content_type :data, :content_type => "application/xml"
  #validates_attachment_content_type :data, content_type: ["application/xml", "text/xml"]

 
  # could include images as well
  # validates_attachment_file_name :data, :matches => [/txt\Z/,/xml\Z/]
  #validates_attachment_file_name :data, matches: %r{\.xml\Z}i
  validates_attachment_file_name :data, matches: [/xml\Z/, /ris\Z/, /txt\Z/]
 
 end
 