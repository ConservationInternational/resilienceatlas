require 'capistrano/rvm'

set :rvm_ruby_version, '2.2.1'
set :rvm_custom_path, '/home/ubuntu/.rvm'

set :linked_files, %w{config/database.yml .env}
set :linked_dirs, %w{public/files public/ckeditor_assets}
set :linked_dirs, fetch(:linked_dirs).push('public/files')
set :linked_dirs, fetch(:linked_dirs).push('public/ckeditor_assets')

server '52.201.131.175', user: 'ubuntu', roles: %w{web app db}, primary: true

set :ssh_options, {
  forward_agent: true,
  auth_methods: %w(publickey)
}

set :rails_env, "production"
set :branch, 'master'
