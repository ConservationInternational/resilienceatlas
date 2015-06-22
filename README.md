# Neptis Geoweb

The Neptis Geoweb is a data-driven,map-based story-tellingand discussion platformtargeted to both the expert and engaged citizen. The primary purpose of Geoweb is to visualize and explore spatial data relating to land use, transportation and environment policies and plans in the Greater Toronto region.

## Installation

Requirements:

* NodeJs 0.10+ [How to install](https://nodejs.org/download/)
* Ruby 2.2.0 [How to install](https://gorails.com/setup/osx/10.10-yosemite)
* PostgreSQL 9+ [How to install](http://exponential.io/blog/2015/02/21/install-postgresql-on-mac-os-x-via-brew/)

Install global dependencies:

    gem install bundler
    npm install -g grunt-cli bower

Install project dependencies:

    bundle install
    npm install

Finally, duplicate `.env.sample` file to `.env` and edit with your options:

    DB_USER=user
    DB_PASS=password
    DEVISE_KEY=secret

## Usage

First time execute:
    
    bundle exec rake db:create
    bundle exec rake db:migrate

To run application:

    bundle exec rails server

## Contributing

1. Fork it!
2. Create your feature branch: `git checkout -b my-new-feature`
3. Commit your changes: `git commit -am 'Add some feature'`
4. Push to the branch: `git push origin my-new-feature`
5. Submit a pull request :D
