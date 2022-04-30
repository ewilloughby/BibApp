# as per, https://github.com/collectiveidea/delayed_job
# as I found the defaults from the console using
# Delayed::Worker.sleep_delay to get an answer
=begin
1.9.3p385 :006 > Delayed::Worker.sleep_delay    => 5
1.9.3p385 :007 > Delayed::Worker.max_attempts   => 25  
1.9.3p385 :008 > Delayed::Worker.max_run_time   => 14400
1.9.3p385 :009 > Delayed::Worker.read_ahead     => 5
1.9.3p385 :010 > Delayed::Worker.delay_jobs     => true
1.9.3p385 :011 > Delayed::Worker.destroy_failed_jobs  => true
=end

# also see
# https://github.com/collectiveidea/delayed_job/blob/master/lib/delayed/worker.rb

# to start up from command line, and run in-process
# bundle exec rake jobs:work 

# **************
# IF ANY DELAYED JOB PARAMS ARE CHANGED, 
# NEED TO STOP AND RESTART DJ ******************
# this makes DJ work synchronously in development
#Delayed::Worker.delay_jobs = !Rails.env.development?

# turning this off in development
if Rails.env.development?
  Delayed::Worker.sleep_delay = 240
  Delayed::Worker.destroy_failed_jobs = false
  Delayed::Worker.max_attempts = 5 
  #asynchronous as in production, but for testing want synchronous, so set following to false to be synchronous
  Delayed::Worker.delay_jobs = true
  #Delayed::Worker.delay_jobs = false
  p "delayed job in development"
  p "Jobs asynchronous: #{Delayed::Worker.delay_jobs}"
else
  Delayed::Worker.sleep_delay = 60
  Delayed::Worker.destroy_failed_jobs = false
  Delayed::Worker.max_attempts = 5 
  p "delayed job in production"
  p "Jobs asynchronous: #{Delayed::Worker.delay_jobs}"
end


#Delayed::Worker.logger = Rails.logger

# in development env, Rails.logger.level == Logger::DEBUG
#Delayed::Worker.logger = ActiveSupport::BufferedLogger.new("log/delayed_jobs_#{Rails.env}.log", Rails.logger.level)
Delayed::Worker.logger = Logger.new("log/delayed_job_#{Rails.env}.log", 5, 104857600)

# following doesn't lessen the logging to development.log
#Delayed::Worker.logger = ActiveSupport::BufferedLogger.new("log/#{Rails.env}_delayed_jobs.log", Logger::ERROR)

# adding this to BibApp 3.2.18 production on Jan 29, 2015
# getting to much info in logs which is set to Logger::INFO -- or 1 as default, ERROR is 3
if Rails.env.production? 
  Delayed::Worker.logger.level = Logger::ERROR
end

if caller.last =~ /script\/delayed_job/ or (File.basename($0) == "rake" and ARGV[0] =~ /jobs\:work/)
  ActiveRecord::Base.logger = Delayed::Worker.logger
end

#Delayed::Worker.logger.auto_flushing = 1 # this will be deprecated in Rails 4, getting warnings
#if caller.last =~ /.*\/script\/delayed_job:\d+$/
#  ActiveRecord::Base.logger = Delayed::Worker.logger
#end


=begin
require 'delayed/worker'

Delayed::Worker.logger = Rails.logger

# debug|info|warn|error|fatal
module Delayed
  class Worker
    def say_with_flushing(text, level = Logger::INFO)
      if logger
        say_without_flushing(text, level)
        logger.flush
      end
    end
    alias_method_chain :say, :flushing
  end
end
=end
