workers Integer(ENV["WEB_CONCURRENCY"] || 2)
threads_count = Integer(ENV["MAX_THREADS"] || 5)
threads threads_count, threads_count

if ENV.fetch("RAILS_ENV") == "development"
  puts "LOGGER: development => worker_timeout 3600"
  worker_timeout 3600
end

preload_app!

port ENV["PORT"] || 3000
environment ENV["RACK_ENV"] || "development"

if ENV.fetch("RAILS_ENV") == "development"
  puts "LOGGER: development => worker_timeout 3600"
  worker_timeout 3600
end
