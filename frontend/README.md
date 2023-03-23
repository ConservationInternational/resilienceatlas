# Resilience Atlas - Front-end

*This version is based on the repository: [https://github.com/ConservationInternational/resilienceatlas-react](https://github.com/ConservationInternational/resilienceatlas-react)*

The front-end application of the Resilience Atlas platform is built using the following resources:

- [React](https://reactjs.org/) as a UI library
- [Next.js](https://nextjs.org/) as a framework
- [Sass](https://sass-lang.com/) as a CSS language
- [Foundation](https://get.foundation/) as a styles framework
- [Redux](https://redux.js.org/) as a state manager
- [Leaflet](https://leafletjs.com/) and [CARTO.js](https://carto.com/developers/carto-js/) as mapping technologies

## Quick start

In order to start modifying the app, please make sure to correctly configure your workstation:

1. Make sure you you have [Node.js](https://nodejs.org/en/) installed
2. (Optional) Install [NVM](https://github.com/nvm-sh/nvm) to manage your different Node.js versions
3. (Optional) Use [Visual Studio Code](https://code.visualstudio.com/) as a text editor to benefit from automatic type checking
4. Configure your text editor with the [Prettier](https://prettier.io/), [ESLint](https://eslint.org/) and [EditorConfig](https://editorconfig.org/) plugins
5. (Optional) Configure your editor to “format [code] on save” with ESLint and Prettier
6. Use the correct Node.js version for this app by running `nvm use`; if you didn't install NVM (step 2), then manually install the Node.js version described in `.nvmrc`
7. Install the dependencies: `yarn`
8. Create a `.env` file at the root of the project by copying `.env.example` and giving a value for each of the variables (see next section for details)
9. Run the server: `yarn dev`

You can access a hot-reloaded version of the app on [http://localhost:3000](http://localhost:3000).

## Environment variables

The application is configured via environment variables stored in a `.env` file that must be placed at the root of the project. You can create one by copying `.env.example` and setting a value for each key.

Below is a description of each of the keys.

| Variable                       | Description                                                                                                                                       |
|--------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------|
| `NEXT_PUBLIC_API_HOST`         | Complete URL of the API server (including https) and without the trailing slask (e.g. https://www.resilienceatlas.org)                            |
| `NEXT_PUBLIC_GOOGLE_ANALYTICS` | Optional − Google Analytics' measurement ID                                                                                                       |

## CI/CD

When a pull request (PR) is created, a GitHub action runs the tests (`yarn test`).

When the PR is merged or commits are directly pushed to the `develop` branch (not recommended), the tests are also run and the application is deployed to the staging environment: https://staging.resilienceatlas.org/.

When a PR is merged to the `main` branch, the same process is also executed and the application is deployed to the production environment: https://www.resilienceatlas.org/.

It is recommended to mention the Jira task ID either in commits or the branch names so that the deployment information can be directly available in Jira.

## Manual deployment

We are using Capistrano to deploy the application. So, in order to deploy the application, you need to have the following:

* Ruby 3.2.1 (rbenv recommended)

And you can install the dependencies with:

```
gem install bundler
bundle install
```

In case you need to manually deploy the application, you can use the following commands:

```
bundle exec cap [staging|production] deploy
```

## Contribution rules

Please, **create a PR** for any improvement or feature you want to add. Use the `develop` branch for this.

## Vulnerability mitigation

[Dependabot's vulnerability security alerts](https://docs.github.com/en/code-security/dependabot/dependabot-alerts/about-dependabot-alerts) are configured in this repository and are displayed to the administrators.

When vulnerabilities are detected, a warning message is displayed at the top of the repository. The list of alerts can be found in the [Dependabot alerts page](https://github.com/Vizzuality/heco-invest/security/dependabot).

Here's a step by step guide on how to address vulnerabilities found in production code:

1. Go to the [Dependabot alerts page](https://github.com/Vizzuality/heco-invest/security/dependabot) and locate the front-end vulnerability to address
2. Identify if the vulnerability affects production code:
   - To do so run `yarn npm audit --recursive --environment production`
   - If the dependency is _not_ listed by this command, then the vulnerability only affects development code. You can dismiss the alert on GitHub as “Vulnerable code is not actually used” in the top right corner of the vulnerability page.
   - If the dependency _is_ listed, follow the steps below.
3. On the vulnerability page, click the “Create Dependabot security update” button
   - This will create a Pull Request with a fix for the vulnerability. If GitHub can generate this PR, then you can merge and the security alert will disappear.
   - If the vulnerability can't be patched automatically, follow the steps below.
4. If the action fails, then you can semi-automatically update the vulnerable dependency by running `npm_config_yes=true npx yarn-audit-fix --only prod`
   - `yarn-audit-fix` (see [repository](https://github.com/antongolub/yarn-audit-fix)) is a tool that applies the fixes from `npm audit fix` to Yarn installations
   - The tool might also not be able to fix the vulnerability. If so, continue with the steps below.
5. If the action fails, then you will have to manually update the dependencies until the vulnerability is solved
