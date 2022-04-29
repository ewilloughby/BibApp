# if this is implemented and user clicks Archive Research on a Works page
# user will be brought to Sword page
# if they upload something, like a txt file or pdf, etc
# it will appear as a download for anyone on the works page

# this code works but hasn't been really tested since we don't have a use case for it
# see
# https://github.com/thoughtbot/paperclip

class ContentFile < Attachment
  # Inherits default settings from Attachment model
  #
  # not sure what content_type as this attachment type would be uploading a content file for Sword
  # but Sword is not implemented in our BibApp
  #  I presume this might be data of type PDF or maybe a spreadsheet or CSV file ??, eg. research related
  
  # an example from http://stackoverflow.com/questions/21897725/papercliperrorsmissingrequiredvalidatorerror-with-rails-4
  #validates_attachment_content_type :image, :content_type => ["image/jpg", "image/jpeg", "image/png", "image/gif"]
  
  # use a mime type
  #validates_attachment_content_type :data, :content_type => [/text\/plain/, /text\/xml/, 
  #   /application\/x-Inst-for-Scientific-Inf/, /application\/x-Research-Info-Systems/]
  #validates_attachment_content_type :data, content_type: ["application/xml", "text/xml"]
  validates_attachment_file_name :data, matches: %r{\.xml\Z}i
  # could include images as well
  #validates_attachment_file_name :data, :matches => [/pdf\Z/, /csv\Z/, /txt\Z/, /xml\Z/]
 
 end
 