# config valid for current version and patch releases of Capistrano
lock "~> 3.17.0"
set :rbenv_ruby, '2.7.6'

set :application, "bibapp"
set :repo_url, "git@github.com:ewilloughby/BibApp.git"

# Default branch is :master
#set :branch,      fetch(:branch, 'main')
set :branch, "main"
# ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

# Default deploy_to directory is /var/www/my_app_name
set :deploy_to, "/Bibapp"

# Setting custom tmpdir
set :tmp_dir, "/Bibapp/tmp"

# Default value for :format is :airbrussh.
# set :format, :airbrussh

# You can configure the Airbrussh format using :format_options.
# These are the defaults.
# set :format_options, command_output: true, log_file: "log/capistrano.log", color: :auto, truncate: :auto

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
# append :linked_files, "config/database.yml", 'config/master.key'

# Default value for linked_dirs is []
# append :linked_dirs, "log", "tmp/pids", "tmp/cache", "tmp/sockets", "tmp/webpacker", "public/system", "vendor", "storage"
append :linked_dirs, 'log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', "tmp/webpacker", 'vendor/bundle', '.bundle', 'public/system', 'public/uploads'
append :linked_files, 'config/database.yml', 'config/master.key', 'config/credentials.yml.enc', 'config/personalize.rb', 'config/solr.yml', 'config/smtp.yml', 'config/locales.yml', 'config/locales/personalize/en.yml'

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for local_user is ENV['USER']
# set :local_user, -> { `git config user.name`.chomp }

# Default value for keep_releases is 5
# set :keep_releases, 5

# Uncomment the following to require manually verifying the host key before first deploy.
# set :ssh_options, verify_host_key: :secure
