set :repo_url, 'https://github.com/ConservationInternational/resilienceatlas.git'

set :rvm_ruby_version, '2.2.1'
set :rvm_custom_path, '/usr/share/rvm'

set :linked_files, %w{config/database.yml .env}
set :linked_dirs, %w{downloads public/ckeditor_assets}

server '52.7.28.202', user: 'ubuntu', roles: %w{web app db}, primary: true

set :ssh_options, {
  forward_agent: true,
  auth_methods: %w(publickey)
}

set :rails_env, "production"
set :branch, 'staging'
