# Resilience Atlas web app

This is the web app powering 
[resilienceatlas.org](http://www.resilienceatlas.org)

## Installation

Requirements:

* Ruby 3.2.1
* PostgreSQL

Install global dependencies:

    gem install bundler

Install project dependencies:

    bundle install

## Usage

Before running the application, you need to configure it by copying `.env.sample` to `.evn` and setting the appropriate values where needed.

### Create database schema

`bin/rails db:create db:migrate db:seed` to setup the database

### Run the server

`bundle exec rails server` and access the project on `http://localhost:3000`

See the generated api docs (described below) for available API endpoints. The backoffice is accessed at `/admin`.

### Run the tests

`bundle exec rspec`

### Run rswag to generate API documentation

`SWAGGER_DRY_RUN=0 rake rswag:specs:swaggerize`

Documentation can be found at `/api-docs`.

### Replace snapshot files

On the first run, the `match_snapshot` matcher will always return success and it will store a snapshot file. On the next runs, it will compare the response with the file content.

If you need to replace snapshots, run the specs with:

`REPLACE_SNAPSHOTS=true bundle exec rspec`

If you only need to add, remove or replace data without replacing the whole snapshot:

`CONSERVATIVE_UPDATE_SNAPSHOTS=true bundle exec rspec`

### Run linters

`bin/rails standard`

To fix linter issues

`bin/rails standard:fix`

## Deployment

In `config/deploy` you will find a sample file. Copy `production.rb.sample` to `production.rb` and change it accordingly. Deploy using:
 
```
bundle exec cap production deploy
```
