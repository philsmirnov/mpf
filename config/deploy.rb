server_address = '37.139.29.122'
set :application, 'mpf'
set :repository, 'https://github.com/philsmirnov/mpf.git'
set :deploy_via, :remote_cache


set :user, 'deploy'
set :use_sudo, false
set (:deploy_to) { "/home/#{user}/apps/#{application}" }

set :scm, :git
set :ssh_options, { :forward_agent => true }

role :web, server_address                           # Your HTTP server, Apache/etc
role :app, server_address                           # This may be the same as your `Web` server
role :db,  server_address, :primary => true # This is where Rails migrations will run

require 'bundler/capistrano'
set :bundle_flags, '--deployment --quiet --binstubs'

set :whenever_command, 'bundle exec whenever'
require 'whenever/capistrano'

set :default_environment, {
    'PATH' => '/usr/local/rbenv/shims:/usr/local/rbenv/bin:$PATH'
}

after 'deploy:restart', 'deploy:cleanup'
after 'deploy:update_code', :copy_fetcher_config, :copy_database_config

set :bundle_cmd, 'bundle'

task :copy_fetcher_config, roles => :app do
  fetcher_config = "#{shared_path}/fetcher_settings.yml"
  run "cp #{fetcher_config} #{release_path}/fetcher_settings.yml"
end

task :copy_database_config, roles => :app do
  db_config = "#{shared_path}/../../mps/shared/database.yml"
  run "cp -f #{db_config} #{release_path}/gdrive_fetcher/database.yml"
end