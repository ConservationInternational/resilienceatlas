server 'staging.resilienceatlas.org', user: 'ubuntu', roles: %w{web app db}, primary: true

set :ssh_options, {
  forward_agent: true,
  auth_methods: %w(publickey)
}

set :node_env, 'production'
set :branch, 'client/fix/deploying-capistrano'
