lock '3.4.0'

set :application, 'CIGRP'
set :repo_url, 'git@github.com:Vizzuality/cigrp-prototype.git'
set :branch, 'experimental/capistrano-config'

set :deploy_to, '/home/ubuntu/cigrp'

set :passenger_restart_with_touch, true

set :rvm_type, :system

namespace :deploy do

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within release_path do
      #   execute :rake, 'cache:clear'
      # end
    end
  end

end
