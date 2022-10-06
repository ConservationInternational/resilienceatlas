lock '3.16.0'

set :application, 'ResilienceAtlas'
set :repo_url, 'git@github.com:ConservationInternational/resilienceatlas.git'
set :branch, 'master'

set :linked_files, %w{.env}
set :linked_dirs, %w{log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system}

set :deploy_to, '/home/ubuntu/resilienceatlas'

set :passenger_restart_with_touch, true

set :nvm_node, 'v13.7.0'
set :nvm_map_bins, %w{node npm}

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

namespace :downloads do
  task :clear do
    on roles(:web), in: :sequence, wait: 10 do
      within release_path do
        execute :rake, 'layers:delete_downloads'
      end
    end
  end
end
