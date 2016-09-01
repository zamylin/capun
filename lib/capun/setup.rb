require 'digest'
set :deploy_to, -> {"/home/#{fetch(:user)}/apps/#{fetch(:application)}"}
set :rvm1_ruby_version, "ruby-2.3.0"
set :branch, 'master'
# Remote caching will keep a local git repository on the server you're deploying to
# and simply run a fetch from that rather than an entire clone
set :deploy_via, :remote_cache
# Capistrano would use local ssh keys to get access to git repo
set :ssh_options, { :forward_agent => true }
set :pty, false

set :keep_releases, 2
set :bundle_flags, "--quiet"

set :linked_dirs, %w{log tmp/pids tmp/cache tmp/sockets public/system}
set :unicorn_config_path, -> { "#{shared_path}/config/unicorn.config.rb" }

set :install_rvm_ruby, true

set :uploads, []
# Lambdas are used for lazy access to variables set later, in stage file
set :std_uploads, [
  # figaro
  {what: "config/application.yml", where: '#{shared_path}/config/application.yml', upload: true, overwrite: true},
  # logstash configs
  {what: "config/deploy/logstash.config.erb", where: '#{shared_path}/config/logstash.config', upload: -> { !!fetch(:addELK) }, overwrite: true},
  # logrotate configs
  {what: "config/deploy/logrotate.config.erb", where: '#{shared_path}/config/logrotate.config', upload: -> { !!fetch(:addlogrotate) }, overwrite: true},
  # basic_authenticatable.rb
  {what: "config/deploy/basic_authenticatable.rb.erb", where: '#{release_path}/app/controllers/concerns/basic_authenticatable.rb', upload: -> { !!fetch(:use_basic_auth) }, overwrite: true},
  # nginx.conf
  {what: "config/deploy/nginx.conf.erb", where: '#{shared_path}/config/nginx.conf', upload: true, overwrite: true},
  # unicorn.config.rb
  {what: "config/deploy/unicorn.config.rb.erb", where: '#{shared_path}/config/unicorn.config.rb', upload: true, overwrite: true},
  # database.yml
  {what: "config/deploy/backup.sh.erb", where: '#{shared_path}/backup.sh', upload: true, overwrite: true},
  # backup.sh.erb
  {what: "config/deploy/drivesink.py", where: '#{shared_path}/drivesink.py', upload: true, overwrite: true},
  # backup.sh.erb
  {what: "config/deploy/database.yml.erb", where: '#{shared_path}/config/database.yml', upload: true, overwrite: true},
  # restart script
  {what: "config/deploy/start.erb", where: '#{release_path}/bin/start', upload: true, overwrite: true},
  # jenkins' config.xml
  {what: "config/deploy/jenkins.config.xml.erb", where: '/var/lib/jenkins/jobs/#{fetch(:application)}/config.xml', upload: -> { !!fetch(:addJenkins) }, overwrite: false},
  # newrelic.yml
  {what: "config/deploy/newrelic.yml.erb", where: '#{shared_path}/config/newrelic.yml', upload: -> { !!fetch(:addNewRelic) }, overwrite: true}
]

set :symlinks, []
set :std_symlinks, [
  {what: "nginx.conf", where: '/etc/nginx/sites-enabled/#{fetch(:application)}'},
  {what: "logstash.config", where: '/etc/logstash/conf.d/#{fetch(:application)}'},
  {what: "logrotate.config", where: '/etc/logrotate.d/#{fetch(:application)}'},
  {what: "database.yml", where: '#{release_path}/config/database.yml'},
  {what: "application.yml", where: '#{release_path}/config/application.yml'},
  {what: "newrelic.yml", where: '#{release_path}/config/newrelic.yml'}
]
namespace :backup do
  desc 'Backup application'
  task :exec do
    on roles(:app) do
      if fetch(:useBackups)
          execute "sudo /home/#{fetch(:user)}/apps/#{fetch(:application)}/shared/backup.sh"
      end
    end
  end
end

desc "Start server"
task :start do
  invoke 'deploy:kill_me'
  invoke 'unicorn:start'
  invoke 'delayed_job:restart' if fetch(:delayed_job)
  invoke 'clockwork:restart' if fetch(:clockwork)
end



namespace :predeploy do
  namespace :install do
    desc 'Install RVM & Ruby'
    task :rvm_ruby do
      puts "install_rvm_ruby: #{fetch(:install_rvm_ruby)}"
      if fetch(:install_rvm_ruby)
        invoke 'rvm1:install:rvm' # install/update RVM
        invoke 'rvm1:install:ruby' # install Ruby and create gemset
      end
    end
  end
end

before 'deploy', 'predeploy:install:rvm_ruby'

namespace :deploy do

  desc 'Kills unicorn processes'
  task :kill_me do
    on roles(:app) do
      execute "cd /home/#{fetch(:user)}/apps/#{fetch(:application)}/shared/tmp/pids; for line in $(ls | grep unicorn); do  kill -15 $(sudo cat $line) || true ; done;"
    end
  end
  before :deploy, 'deploy:kill_me'

  desc 'Uploads files to app based on stage'
  task :upload do
    on roles(:app) do |server|
      # create /home/[user]/apps/[app]/shared/config directory, if it doesn't exist yet
      execute :mkdir, "-p", "#{shared_path}/config"
      execute :sudo, :chown, "-R", "#{fetch(:user)}:#{fetch(:user)}", "#{shared_path}/config/."
      uploads = fetch(:uploads).concat(fetch(:std_uploads))
      uploads.each do |file_hash|
        # file_hash[:upload] may be either a boolean or a lambda; in the latter case we use its result
        next if !file_hash[:upload] || ( file_hash[:upload].is_a?(Proc) && !file_hash[:upload].call )
        what = file_hash[:what]
        next unless File.exists?(what)
        where = eval "\"" + file_hash[:where] + "\""
        next if !file_hash[:overwrite] && test("[ -f #{where} ]")
        # compile template if it ends with .erb before upload
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
      if fetch(:addJenkins) && !test("[ -d /var/lib/jenkins/jobs/#{fetch(:application)}/ ]")
        execute :sudo, :mkdir, "-p", "/var/lib/jenkins/jobs/#{fetch(:application)}"
        execute :sudo, :chown, "#{fetch(:user)}", "/var/lib/jenkins/jobs/#{fetch(:application)}"
      end
    end
  end

  desc "Checking if Jenkins configuration file"
  task :check_jenkins_project_existence do
    on roles(:app) do
      if fetch(:addJenkins) && test("[ -f /var/lib/jenkins/jobs/#{fetch(:application)}/config.xml ]")
        set :jenkins_project_exists, true
      else
        set :jenkins_project_exists, false
      end
    end
  end

  desc 'Setting up Jenkins'
  task :set_up_jenkins do
    if fetch(:addJenkins)
      on roles(:app) do
        if test("[ -f /var/lib/jenkins/jobs/#{fetch(:application)}/config.xml ]")
          execute :sudo, :chown, "jenkins:jenkins", "/var/lib/jenkins/jobs/#{fetch(:application)}"
          execute :sudo, :chmod, "755", "/var/lib/jenkins/jobs/#{fetch(:application)}"
          execute :sudo, :chown, "jenkins:jenkins", "/var/lib/jenkins/jobs/#{fetch(:application)}/config.xml"
          execute :sudo, :chmod, "644", "/var/lib/jenkins/jobs/#{fetch(:application)}/config.xml"
          execute :sudo, "service jenkins restart" unless fetch(:jenkins_project_exists)
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

  desc 'Update cron backup task'
  task :update_cron do
    if fetch(:useBackups)
      on roles(:app) do
        execute :chmod, "+x #{shared_path}/backup.sh"
        info "making backup.sh executable"
        execute :sudo, :ln, "-nfs", "#{shared_path}/backup.sh /etc/cron.#{fetch(:backupTime)}/backup-#{fetch(:application).gsub(/\./, '-')}"
        info "Create symbolic link for backup"
      end
    end
  end

  desc 'Setting up autorestart'
  task :autorestart do
    if fetch(:autorestart)
      on roles(:app) do
        execute :chmod, "+x #{release_path}/bin/start"
        info "making start executable"
        execute :sudo, :ln, "-nfs", "#{release_path}/bin/start /etc/autostart/autorestart-#{fetch(:application).gsub(/\./, '-')}"
        info "Create symbolic link for autorestart"
      end
    end
  end
end

before "deploy:updating", "deploy:make_dirs"
before "deploy:updating", "deploy:check_jenkins_project_existence"
after "deploy:symlink:linked_dirs", "deploy:upload"
after "deploy:symlink:linked_dirs", "deploy:add_symlinks"
after "deploy:publishing", "deploy:set_up_jenkins"
after "deploy:publishing", "deploy:prepare_logrotate"
after "deploy:publishing", "deploy:autorestart"
after "deploy:publishing", "deploy:restart_nginx"
after "deploy:publishing", "deploy:restart_logstash"
after "deploy:publishing", "deploy:update_cron"
after "deploy:publishing", "unicorn:legacy_restart"
