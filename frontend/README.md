# Resilience Atlas web app

This is the web app powering
[resilienceatlas.org](http://www.resilienceatlas.org)


## Requirements:

- NodeJs 11.9.0+ [How to install](https://nodejs.org/download/)
- npm 6.9.0+
- yarn 1.13.0+ (you can use npm instead)

## Start here if your machine already has Requirements Installed, If you need help with installation, scroll to bottom
Install project dependencies:

    yarn

## Usage

Before running the application, you need to configure it by copying `.env.example` to `.env` and setting the appropriate values where needed.

To start the application, run:

    yarn start

## Production build

To compile production build, run:

    yarn build

and then you can use your production build locally:

    npm i -g serve
    serve -s build

## Deploy (Capistrano)

You need ruby 2.5.3, then you have to install gems using `bundle install`. To deploy to staging you have to run:

```
	gem install bundler -v 1.17.3
	bundle install
    bundle exec cap staging deploy
```

As the deploy task takes a lot of memory we have to run the compilation separately, go to the `current` folder and run the next command:

```
	cd ~/resilience-react/current
	npm run --max_old_space_size=4000 build
```
## Set-up your Device

### In a Virtual Machine (Windows 10)

#### Enable Hyper-V
1) Navigate to 'Apps and Features"
2) Select *Programs and Features* on the right under related settings
3) Select *Turn Windows Features on and Off*
4) Select *Hyper-V* and click *ok*

#### Create a Virtual Machine (Ubuntu 20.04.1 LTS)
1) [Download Ubuntu Desktop](https://ubuntu.com/download/desktop)
2) Navigate to *Hyper-V Manager* (If you have Admin Priveleges, you can use Hyper-V Quick Create)
3) In *Hyper-V Manager* click *Action* dropdown on top navigation bar and select *Virtual Switch Manager*
4) Accept External Switch Defaults and Name it Something Personal eg. (YourName-VirtualSwitch)
5) Click *Action* dropdown on top navigation bar and select *New/VirtualMachine*
6) This Creation Wizard is Pretty Intuitive. A few settings to remember, in the order that you'll need them:
	- SpecifyNameAndLocation: Name the virtual machine something memorable. I recommend a combination of project name and ubuntu20.04.1
	- SpecifyGeneration: Generation 1
	- AssignMemory: Ubuntu Requires a Minimum of *2000 MB* of Starter Memory to Run Effectively.
	- ConfigureNetworking: Select your custom Switch here
	- InstallationOptions: Install Operating System from Bootable CD/DVD, Navigate to .iso file downloaded in Step 1
	- Finish
7) Start Virtual Machine

#### Install Packages

In this section we will be installing the dependencies from the Requirements Section Above onto your Virtual Machine
1) Open Terminal by navigating through applications in the grid dot logo at the bottom of your screen.
2) Run the following commands:
	- apt sudo install git
	- apt sudo install ruby
	- apt sudo install npm
	- apt sudo install nodejs
	- curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
	-echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list

3) Clone resilience-react repo to this machine using
  git clone https://github.com/ConservationInternational/resilienceatlas-react.git

### On Your Local Machine (Windows 10)

I recommend installing [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git) and using git Bash for installation. Although Using whatever command line tool you're most comfortable in will probably work as well.

1) Install [Ruby](ruby-lang.org/en/documentation/installation)
2) Install [node](nodejs.org/en/download)
3) Install [yarn](classic.yarnpkg.com/en/docs/install/#windows-stable)
4) git clone https://github.com/ConservationInternational/resilienceatlas-react.git


## Contributing

1. Fork it!
2. Create your feature branch: `git checkout -b feature/my-new-feature`
3. Commit your changes: `git commit -am '[Feature] Add some feature'`
4. Push to the branch: `git push origin feature/my-new-feature`
5. Submit a pull request :D
