lock "~> 3.17.0"

set :application, "ResilienceAtlas"
set :repo_url, "git@github.com:ConservationInternational/resilienceatlas.git"
set :repo_tree, "backend"
set :branch, "master"

set :linked_files, %w[config/database.yml .env]
set :linked_dirs, %w[log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system public/storage public/uploads public/ckeditor_assets downloads]

set :deploy_to, "/home/ubuntu/resilienceatlas"

set :passenger_restart_with_touch, true

set :rbenv_type, :user # or :system, or :fullstaq (for Fullstaq Ruby), depends on your rbenv setup
set :rbenv_ruby, "3.2.1"
set :rbenv_prefix, "RBENV_ROOT=#{fetch(:rbenv_path)} RBENV_VERSION=#{fetch(:rbenv_ruby)} #{fetch(:rbenv_path)}/bin/rbenv exec"
set :rbenv_map_bins, %w[rake gem bundle ruby rails]
set :rbenv_roles, :all

namespace :deploy do
  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within release_path do
      #   execute :rake, "cache:clear"
      # end
    end
  end
end

namespace :downloads do
  task :clear do
    on roles(:web), in: :sequence, wait: 10 do
      within release_path do
        execute :rake, "layers:delete_downloads"
      end
    end
  end
end

# for the bastion host
require "net/ssh/proxy/command"

# Use a default host for the bastion, but allow it to be overridden
bastion_host = ENV["BASTION_HOST"] || "login.resilienceatlas.org"

# Use the local username by default
bastion_user = ENV["BASTION_USER"] || "ubuntu"

# Configure Capistrano to use the bastion host as a proxy
ssh_command = "ssh -o StrictHostKeyChecking=no #{bastion_user}@#{bastion_host} -W %h:%p"
set :ssh_options, proxy: Net::SSH::Proxy::Command.new(ssh_command)
