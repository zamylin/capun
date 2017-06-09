# encoding: utf-8
require 'rails/generators/base'

module Capun
  module Generators
    class StageGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("../templates", __FILE__)
      desc "Adds stage to capistrano configuration"

      def opts
        @appname = ask("Application name for stage \"#{singular_name}\" [ex.: beta.myapp]:")
        @url = ask("Domain name where application for stage \"#{singular_name}\" would be deployed [ex.: beta.myapp.com]:")
        @addauth = ask("Would you like to add basic authentication to stage? [Y/n]").capitalize == 'Y'
        if @addauth
          @username = ask("Basic authentication username [ex.: mike]:")
          @password = ask("Basic authentication password [ex.: secret]:")
        end
        @addJenkins = ask("Would you like to add Jenkins configuration file? [Y/n]").capitalize == 'Y'
        @addNewRelic = ask("Would you like to add New Relic configuration file? [Y/n]").capitalize == 'Y'
        if @addNewRelic
          @newRelicKey = ask("New relic key:")
        end
        @addELK = ask("Would you like to add ELK-compatible logging? [Y/n]").capitalize == 'Y'
        @addlogrotate = ask("Would you like to add logrotate configuration to stage? [Y/n]").capitalize == 'Y'
        @useBackups = ask("Would you like to add amazon backup system? [Y/n]").capitalize == 'Y'
        @addDelayedJob = ask("Would you like to add delayed job worker? [Y/n]").capitalize == 'Y'
        @addClockwork = ask("Would you like to add clockwork worker? [Y/n]").capitalize == 'Y'
        @autorestart = ask("Would you like to start application after server restart? [Y/n]").capitalize == 'Y'
      end

      def add_stage
        template "stage.rb.erb", "config/deploy/#{singular_name}.rb"
      end


      def copy_env_file
        copy_file Rails.root.join('config', 'environments', 'production.rb'), "config/environments/#{singular_name}.rb"
      end

      def add_authentication
        if @addauth
          template "basic_authenticatable.rb.erb", "config/deploy/basic_authenticatable.rb.erb"
          # inject include directive
          app_controller = "app/controllers/application_controller.rb"
          this_text = "  include BasicAuthenticatable if File.exists?( File.expand_path('../concerns/basic_authenticatable.rb', __FILE__) )\n"
          this_line = "class ApplicationController < ActionController::Base\n"
          gsub_file app_controller, this_text, ''
          inject_into_file app_controller, this_text, after: this_line
          #inject use auth flag into stage
          gsub_file "config/deploy/#{singular_name}.rb", "\nset :use_basic_auth, true", '' if File.exists?("./config/deploy/#{singular_name}.rb")
          append_to_file "config/deploy/#{singular_name}.rb", "\nset :use_basic_auth, true" if File.exists?("./config/deploy/#{singular_name}.rb")
        end
      end

      def add_secret
        if File.exists?("config/secrets.yml")
          secret_token_does_not_exist = Thor::CoreExt::HashWithIndifferentAccess.new(::YAML::load_file("config/secrets.yml"))[singular_name].nil?
          if secret_token_does_not_exist
            append_to_file "config/secrets.yml", "\n#{singular_name}:\n  secret_key_base: #{SecureRandom.hex(64)}"
          end
        end
      end

      def add_ELK
        if @addELK
          #coping logstash config
          copy_file "logstash.config.erb", "config/deploy/logstash.config.erb"
          #installing required gems
          gem "lograge"
          gem "logstash-event"
          inside Rails.root do
            run "bundle install --quiet"
          end
          #adding lograge configs to relevant environment initializer
          inject_into_file "config/environments/#{singular_name}.rb", File.read(File.expand_path("../templates/lograge_env_config.excerpt", __FILE__)), :before => /^end/
          #adding append_info_to_payload method override to pipe required information to lograge log
          this_line = "class ApplicationController < ActionController::Base\n"
          inject_into_file "app/controllers/application_controller.rb", File.read(File.expand_path("../templates/append_info.excerpt", __FILE__)), :after => this_line
          #coping logstash config
          copy_file "lograge_initializer.rb", "config/initializers/lograge_initializer.rb"
          #adding flag to run 'service logstash restart' during deploy
          append_to_file "config/deploy/#{singular_name}.rb", "\nset :addELK, true"
        end
      end

      def add_logrotate
        if @addlogrotate
          copy_file "logrotate.config.erb", "config/deploy/logrotate.config.erb"
          append_to_file "config/deploy/#{singular_name}.rb", "\nset :addlogrotate, true"
        end
      end

      def useBackups
        if @useBackups
          append_to_file "config/deploy/#{singular_name}.rb", "#backup_system\n" +
          "set :useBackups, true\n" +
          "set :backupTime, \"daily\" # available hourly, daily, monthly, weekly\n" +
          "set :backupFolders, %w{public/system} #recursive\n" +
          "#set :slack_hook, [hook]\n" +
          "#set :slack_channel, [channel] #must be specified"+
          "#set :backup_telegram_bot_hash, [channel] #must be specified"+
          "#set :bachup_telegram_chat_id, [channel] #must be specified"
          copy_file "backup.sh.erb", "config/deploy/backup.sh.erb"
          copy_file "drivesink.py", "config/deploy/drivesink.py"
        end
      end

      def addDelayedJob
        if @addDelayedJob
          append_to_file "config/deploy.rb","set :delayed_job, true\n"
          append_to_file "Gemfile","gem 'delayed_job'\n"
          append_to_file "Gemfile","gem 'delayed_job_active_record'\n"
          append_to_file "Gemfile","gem 'capistrano3-delayed-job', '~> 1.0'\n"
        end
      end
      def addClockwork
        if @addClockwork
          append_to_file "config/deploy.rb","set :clockwork, true\n"
          append_to_file "Gemfile","gem 'clockwork'\n"
          append_to_file "Gemfile","gem 'capistrano-clockwork'\n"
        end
      end
      def addAutorestart
        if @autorestart
          append_to_file "config/deploy/#{singular_name}.rb", "set :autorestart, true\n"
        end
      end
      def add_jenkins
        if @addJenkins
          copy_file "jenkins.config.xml.erb", "config/deploy/jenkins.config.xml.erb"
          jenkinsToken = Digest::MD5.hexdigest(@appname + Time.now.to_f.to_s)
          append_to_file "config/deploy/#{singular_name}.rb", "\nset :addJenkins, true\nset :jenkinsToken, \"#{jenkinsToken}\""
        end
      end

      def add_newrelic
        if @addNewRelic
          copy_file "newrelic.yml.erb", "config/deploy/newrelic.yml.erb"
          gem "newrelic_rpm"
          inside Rails.root do
            run "bundle install --quiet"
          end
          append_to_file "config/deploy/#{singular_name}.rb", "\nset :addNewRelic, true\nset :newRelicKey, \"#{@newRelicKey}\""
        end
      end
    end
  end
end
