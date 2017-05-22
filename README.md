# Resilience Atlas web app

This is the web app powering 
[resilienceatlas.org](http://www.resilienceatlas.org)

## Installation

Requirements:

* NodeJs 0.10+ [How to install](https://nodejs.org/download/)
* Ruby 2.2.0 [How to install](https://gorails.com/setup/osx/10.10-yosemite)
* PostgreSQL

Install global dependencies:

    gem install bundler
    npm install -g grunt-cli bower

Install project dependencies:

    bundle install
    npm install

## Usage

Before running the application, you need to configure it by copying `.env.sample` to `.evn` and setting the appropriate values where needed.

To start the application, run:

```
bundle exec rails server
```

## Deployment

In `config/deploy` you will find a sample file. Copy `production.rb.sample` to `production.rb` and change it accordingly. Deploy using:
 
```
bundle exec cap production deploy
```

## Deploy advice
As we remove bower to manage front dependencies, now it's necesary to change it at Heroku. Apparently, only owner can do it. So for the moment we need a fake bower.json file in order the deploy to work. Please, don't remove it before Heroku is fixed. 
(Clara, 17/08/2015)

## Contributing

1. Fork it!
2. Create your feature branch: `git checkout -b my-new-feature`
3. Commit your changes: `git commit -am 'Add some feature'`
4. Push to the branch: `git push origin my-new-feature`
5. Submit a pull request :D
