require 'digest'
set :deploy_to, -> {"/home/#{fetch(:user)}/apps/#{fetch(:application)}"}
set :rvm1_ruby_version, "2.0.0"
set :branch, 'master'
# Remote caching will keep a local git repository on the server you're deploying to
# and simply run a fetch from that rather than an entire clone
set :deploy_via, :remote_cache
# Capistrano would use local ssh keys to get access to git repo
set :ssh_options, { :forward_agent => true }
set :pty, false

set :keep_releases, 2
set :bundle_flags, "--quiet"

set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets public/system}
set :unicorn_config_path, -> { "#{shared_path}/config/unicorn.config.rb" }

set :uploads, []
set :std_uploads, [
  #figaro
  {what: "config/application.yml", where: '#{shared_path}/config/application.yml'},
  #logstash configs
  {what: "config/deploy/logstash.config.erb", where: '#{shared_path}/config/logstash.config'},
  #logrotate configs
  {what: "config/deploy/logrotate.config.erb", where: '#{shared_path}/config/logrotate.config'},
  #basic_authenticatable.rb
  {what: "config/deploy/basic_authenticatable.rb.erb", where: '#{release_path}/app/controllers/concerns/basic_authenticatable.rb'},
  #nginx.conf
  {what: "config/deploy/nginx.conf.erb", where: '#{shared_path}/config/nginx.conf'},
  #unicorn.config.rb
  {what: "config/deploy/unicorn.config.rb.erb", where: '#{shared_path}/config/unicorn.config.rb'},
  #secret_token.rb
  {what: "config/initializers/secret_token.rb", where: '#{release_path}/config/initializers/secret_token.rb'},
  #database.yml
  {what: "config/deploy/database.yml.erb", where: '#{shared_path}/config/database.yml'},
  #jenkins' config.xml
  {what: "config/deploy/jenkins.config.xml.erb", where: '#{shared_path}/config/jenkins.config.xml'},
  #newrelic.yml
  {what: "config/deploy/newrelic.yml.erb", where: '#{release_path}/config/newrelic.yml'}
]

set :symlinks, []
set :std_symlinks, [
  {what: "nginx.conf", where: '/etc/nginx/sites-enabled/#{fetch(:application)}'},
  {what: "logstash.config", where: '/etc/logstash/conf.d/#{fetch(:application)}'},
  {what: "logrotate.config", where: '/etc/logrotate.d/#{fetch(:application)}'},
  {what: "database.yml", where: '#{release_path}/config/database.yml'},
  {what: "application.yml", where: '#{release_path}/config/application.yml'},
  {what: "jenkins.config.xml", where: '/var/lib/jenkins/jobs/#{fetch(:application)}/config.xml'}
]

before 'deploy', 'rvm1:install:rvm'  # install/update RVM
before 'deploy', 'rvm1:install:ruby' # install Ruby and create gemset

namespace :deploy do

  desc 'Kills running processes'
  task :kill_me do
    on roles(:app) do
      execute "kill -9 $(ps aux | grep #{fetch(:application)} | grep -v grep | awk '{print $2}') || true"
    end     
  end
  before :deploy, 'deploy:kill_me'

  desc 'Uploads files to app based on stage'
  task :upload do
    on roles(:app) do |server|
      #create /home/[user]/apps/[app]/shared/config directory, if it doesn't exist yet
      execute :mkdir, "-p", "#{shared_path}/config"
      execute :sudo, :chown, "#{fetch(:user)}:#{fetch(:user)}", "#{shared_path}/config/*"
      uploads = fetch(:uploads).concat(fetch(:std_uploads))
      uploads.each do |file_hash|
        what = file_hash[:what]
        next if !File.exists?(what)
        where = eval "\"" + file_hash[:where] + "\""
        #compile temlate if it ends with .erb before upload
        upload! (what.end_with?(".erb") ? StringIO.new(ERB.new(File.read(what)).result(binding)) : what), where
        info "copying: #{what} to: #{where}"
      end
    end
  end

  desc "Makes files executable and creates symlinks according to rules specified in symlinks array"
  task :add_symlinks do
    on roles(:app) do
      symlinks = fetch(:symlinks).concat(fetch(:std_symlinks))
      fetch(:symlinks).each do |file_hash|
        if test("[ -f #{shared_path}/config/#{file_hash[:what]} ]")
          where = eval "\"" + file_hash[:where] + "\""
          execute :chmod, "+x #{shared_path}/config/#{file_hash[:what]}"
          info "making #{file_hash[:what]} executable"
          execute :sudo, :ln, "-nfs", "#{shared_path}/config/#{file_hash[:what]} #{where}"
          info "creating symlink for #{file_hash[:what]} to #{where}"
        end
      end
    end
  end

  desc "Creates necessary directory structury for application"
  task :make_dirs do
    on roles(:app) do
      execute :mkdir, "-p", "/home/#{fetch(:user)}/apps/#{fetch(:application)}"
    end
  end

  desc 'Setting up Jenkins'
  task :set_up_jenkins do
    if fetch(:addJenkins)
      on roles(:app) do
        unless test("[ -f /var/lib/jenkins/jobs/#{fetch(:application)}/config.xml ]")
          # info "Creating Jenkins directory"
          # execute :sudo, :mkdir, "-p", "/var/lib/jenkins/jobs/#{fetch(:application)}"
          # execute :sudo, :chown, "#{fetch(:user)}:#{fetch(:user)}", "/var/lib/jenkins/jobs/#{fetch(:application)}"
          # upload! StringIO.new(ERB.new(File.read("config/deploy/jenkins.config.xml.erb")).result(binding)), "/var/lib/jenkins/jobs/#{fetch(:application)}/config.xml"
          execute :sudo, :chown, "jenkins:jenkins", "/var/lib/jenkins/jobs/#{fetch(:application)}"
          execute :sudo, :chmod, "755", "/var/lib/jenkins/jobs/#{fetch(:application)}"
          execute :sudo, :chown, "jenkins:jenkins", "/var/lib/jenkins/jobs/#{fetch(:application)}/config.xml"
          execute :sudo, :chmod, "644", "/var/lib/jenkins/jobs/#{fetch(:application)}/config.xml"
          execute :sudo, "service jenkins restart"
        end
      end
    end
  end

  desc 'Prepare logrotate'
  task :prepare_logrotate do
    if fetch(:addlogrotate)
      on roles(:app) do
        execute :sudo, :chown, "root:root", "#{shared_path}/config/logrotate.config"
        execute :sudo, :chmod, "644", "#{shared_path}/config/logrotate.config"
      end
    end
  end

  desc 'Restart nginx'
  task :restart_nginx do
    on roles(:app) do
      execute :sudo, "service nginx reload"
    end
  end

  desc 'Restart logstash'
  task :restart_logstash do
    if fetch(:addELK)
      on roles(:app) do
        execute :sudo, "service logstash restart"
      end
    end
  end

end

before "deploy:updating", "deploy:make_dirs"
after "deploy:symlink:linked_dirs", "deploy:upload"
after "deploy:symlink:linked_dirs", "deploy:add_symlinks"
after "deploy:publishing", "deploy:set_up_jenkins"
after "deploy:publishing", "deploy:prepare_logrotate"
after "deploy:publishing", "deploy:restart_nginx"
after "deploy:publishing", "deploy:restart_logstash"
after "deploy:publishing", "unicorn:restart"
