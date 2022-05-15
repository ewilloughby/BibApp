source "https://rubygems.org"
ruby '2.7.6'

#Rails itself
gem "rails", "~> 6.0.4"

gem 'nokogiri', '>= 1.13.5'

#Use jquery for javascript - in Rails 3.0 this involves running a generator too
#once we get to 3.1 all that should be necessary is adding some includes
#to the application.js file in assets
gem 'jquery-rails'

gem 'rake'

#Haml - Haml plugin will fail initialization if haml gem is not installed.
gem "haml"

#Make resourceful - used by some controllers 
#backports may be needed by a 1.8 ruby to make make_resourceful work
#gem 'make_resourceful'
gem "make_resourceful", github: "hcatlin/make_resourceful", branch: "main"

# For Solr Atomic Updates/Indexing
gem 'typhoeus', '>= 1.4.0'
gem 'rest-client', '2.0.2'

#file attachment - to replace attachment_fu
#TODO Can remove version requirement after 1.9 migration
#gem 'kt-paperclip'
#gem "kt-paperclip", "~> 6.4", ">= 6.4.1"
gem "kt-paperclip"
gem "htmlentities"

#Namecase - converts strings to be properly cased
gem "namecase"

#Sword2Ruby - used for SWORD interaction
gem "sword2ruby", ">=0.0.6", :git => 'https://github.com/BibApp/sword2ruby.git'

#Solr-Ruby - Solr connections for ruby
gem "solr-ruby"

#Required for LDAP lookups
gem "net-ldap"

#Will Paginate - for fancy pagination
#TODO may need to update or replace as rails version goes up
gem 'will_paginate'

# Broken out in Rails 4 into a separate Gem
gem 'activerecord-session_store'
gem 'rails-observers'

# Need Zip Capability, RubyZip - used to create Zip file to send via SWORD
gem 'rubyzip'
gem 'zip'

#CMess - Assists with handling parsing citations from a non-Unicode text file
#  See: http://prometheus.rubyforge.org/cmess/
gem 'cmess'

#AASM - Acts as State Machine - helps manage batch import state
gem 'aasm'

#lisbn - Helps validate ISBNs - as far as I can tell this is able to replace previously used ISBN_tools with minor
#modifications
gem 'lisbn'

# hash comparison for SOLR
gem 'hashdiff', '0.3.2'

#delayed jobs
gem 'delayed_job'
gem 'delayed_job_active_record' #, "~> 0.3.2"

gem 'daemons' #, '1.1.9'

#data structures
gem 'acts_as_list'
gem 'acts_as_tree'

#Rails translations
gem 'rails-i18n'

#Change this as appropriate if you are using a different database
#You can also use groups to set it differently for development and
#production, for example. Note that the appropriate database for your
#set up does need to be specified here, though, or things will fail
#pretty quickly.
#gem 'pg'

gem 'mysql2', '0.5.3'

#dump database in YAML form - honestly, I'm not sure why we need this, but
#while I am porting to Rails 3 I'm not going to worry about it.
gem 'yaml_db'

# Puma
gem 'puma'

#replacing authorization with cancancan
gem 'cancancan'

#authentication
# Replaced authlogic with Devise
gem 'devise'

#TODO will require some work to go to 1.0 series
gem 'omniauth'

#batch loading of authors
gem 'fastercsv'

#Adds in some things removed from Rails 3 that are used, including error_messages_for
gem 'dynamic_form'

#Sorting help for different locales.
#Note that sort_alphabetical is a bit crude. It should suffice for latin locales, though.
#If we need something more sophisticated then sort_by_alphabet may be helpful, or keep watch
#for other developments in this area
gem 'sort_alphabetical'

#allow for HTML sanitizing for fields where we want to allow some html
gem 'loofah-activerecord'

gem 'listen'

group :development do

  # deployment
  gem "capistrano", "~> 3.10", require: false
  gem "capistrano-rails", "~> 1.6", require: false
  gem 'capistrano-passenger'
  gem 'capistrano-rbenv', '~> 2.2'
  gem 'ed25519', '~> 1.2.4'
  gem 'bcrypt_pbkdf', '~> 1.1.0'

  #If you want to use newrelic for profiling you can uncomment the following.
  #HOWEVER - generating Gemfile.lock with it uncommented can mess up deployment,
  #so whenever adding new Gems or otherwise generating a new Gemfile.lock to check in
  #please recomment it out!
  #  if File.exist?(File.join(File.dirname(__FILE__), 'config', 'newrelic.yml'))
  #    gem 'newrelic_rpm'
  #  end
  #We use a custom version of tolk for three reasons:
  # - some necessary requires are missing from the main version
  # - we filter the personalize keys so that Tolk doesn't sync them
  # - we don't generate a new migration - the migration for tolk is committed into Bibapp itself
#  gem 'tolk', "~> 1.0.1", :git => 'git://github.com/BibApp/tolk.git'
end

group :test, :development do
  gem 'database_cleaner'
  gem 'rspec'
  gem 'rspec-rails'
  gem 'email_spec'
  #gem 'ruby-debug-base19'
  #gem 'ruby-debug19'
  #gem 'ruby-debug-ide19'
  gem 'byebug'
  gem 'shoulda'
  gem 'factory_bot'
  gem 'simplecov'
  gem 'test-unit'

  #I'd prefer to add metric_fu directly here, but something it pulls
  #in pulls in something else that conflicts with the Keyword class.
  #So instead I've installed the metrical gem separately to see
  #if I can get it to work that way.
  #gem 'metric_fu

end

group :test do
  'gem cucumber-rails, require: false'
end
