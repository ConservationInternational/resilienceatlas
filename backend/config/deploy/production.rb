set :rbenv_type, :user # or :system, or :fullstaq (for Fullstaq Ruby), depends on your rbenv setup
set :rbenv_ruby, "3.0.4"

set :rbenv_prefix, "RBENV_ROOT=#{fetch(:rbenv_path)} RBENV_VERSION=#{fetch(:rbenv_ruby)} #{fetch(:rbenv_path)}/bin/rbenv exec"
set :rbenv_map_bins, %w[rake gem bundle ruby rails]
set :rbenv_roles, :all

set :default_env, {path: "PATH=$PATH:/home/ubuntu/.nvm/versions/node/v13.7.0/bin"}

set :linked_files, %w[config/database.yml .env]
set :linked_dirs, %w[downloads public/ckeditor_assets]

server "52.54.50.38", user: "ubuntu", roles: %w[web app db], primary: true

set :ssh_options, {
  forward_agent: true,
  auth_methods: %w[publickey]
}

set :rails_env, "production"
set :branch, "master"
