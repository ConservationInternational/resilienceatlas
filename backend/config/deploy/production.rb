server "app.resilienceatlas.org", user: "ubuntu", roles: %w[web app db], primary: true

set :rails_env, "production"
set :branch, "master"
