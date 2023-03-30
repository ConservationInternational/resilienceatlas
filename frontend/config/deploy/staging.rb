server 'staging.resilienceatlas.org', user: 'ubuntu', roles: %w[web app db], primary: true

set :node_env, 'production'
set :branch, 'develop'
