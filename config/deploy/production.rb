require 'capistrano/rvm'

set :rvm_ruby_version, '2.2.1'
set :rvm_custom_path, '/home/user/.rvm'

set :linked_files, %w{config/database.yml .env}

server '52.201.131.175', user: 'ubuntu@52.201.131.175', roles: %w{web app db}, primary: true

set :ssh_options, {
  forward_agent: true,
  auth_methods: %w(publickey)
}

set :rails_env, "production"
set :branch, 'feature/sites'
