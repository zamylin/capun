require 'rails/generators/base'

module Capun
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("../templates", __FILE__)

      desc "Adds files and dependencies for complete Capistrano deployment mechanism"

      def opts
        @user = ask("The SSH username you are logging into the server(s) as [ex.: mike]:")
        @server = ask("Server ip-address [ex.: 92.134.223.012]:")
        @repo = ask("The URL of the repository that hosts the code [ex.: git@github.com/capistrano/capistrano.git]:")
      end

      def copy_files
        empty_directory "config/deploy"
        copy_file "database.yml.erb", "config/deploy/database.yml.erb"
        copy_file "unicorn.config.rb.erb", "config/deploy/unicorn.config.rb.erb"
        copy_file "nginx.conf.erb", "config/deploy/nginx.conf.erb"
        copy_file "Capfile", "Capfile"
      end

      def add_to_gitignore
        gsub_file ".gitignore", "\nconfig/deploy/database.yml.erb", '' if File.exists?("./.gitignore")
        append_to_file ".gitignore", "\nconfig/deploy/database.yml.erb" if File.exists?("./.gitignore")
      end

      def remove_production_from_database
        text2remove = "production:\n  adapter: sqlite3\n  database: db/production.sqlite3\n  pool: 5\n  timeout: 5000"
        gsub_file "config/database.yml", text2remove, '' if File.exists?("./config/database.yml")
      end

      def compile_and_add_deploy
        template "deploy.rb.erb", "config/deploy.rb"
      end

    end
  end
end
