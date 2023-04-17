# Resilience Atlas - Front-end

_This version is based on the repository: [https://github.com/ConservationInternational/resilienceatlas-react](https://github.com/ConservationInternational/resilienceatlas-react)_

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

| Variable                       | Description                                                                                                            |
| ------------------------------ | ---------------------------------------------------------------------------------------------------------------------- |
| `NEXT_PUBLIC_API_HOST`         | Complete URL of the API server (including https) and without the trailing slask (e.g. https://www.resilienceatlas.org) |
| `NEXT_PUBLIC_GOOGLE_ANALYTICS` | Optional − Google Analytics' measurement ID                                                                            |
| `NEXT_PUBLIC_TRANSIFEX_TOKEN`  | Token needed for the transifex translation service                                                                     |
| `NEXT_PUBLIC_TRANSIFEX_SECRET` | Secret needed for the transifex translation service                                                                    |
| `NEXT_PUBLIC_STATIC_JOURNEYS`  | Optional − Temporary - Static journey API different from the Backend one but used on production                        |

### How to update the environment variables

Every time we update the environment variables, we need to update them in the following places:

- For the Github actions scripts the environment variables are stored in the repository as GitHub secrets. In order to update them, you need to be an administrator of the repository. And also you need to update the environment variables in the GitHub actions scripts in the `.github/workflows/frontend_ci_cd.yml` file.
- For the staging and production environments, the environment variables are stored in the server as environment variables. In order to update them, you need to be an administrator of the server. The environment variables are stored in the file `[project_path]/shared/.env.production`.
- For the local environment, the environment variables are stored in the `.env.local` file.
- Update the environment variables in the `README.md` file.
- Finally, you have to update the environment variables in the `.env.example` file.

## Translation

The application is translated with the [Transifex Native](https://www.transifex.com/native/) service.

### Initialization

Transifex is initialized on the App.jsx file. A PseudoTranslationPolicy is provided on the development environment so we can see what translations are missing on the different languages directly on the platform on development.

### Scripts

There are three different scripts that use the transifex cli:

- `yarn transifex:push` Pushes the strings that are used in the code to transifex.
- `yarn transifex:push:prod` Pushes the strings that are used in the code to transifex using the production env. This runs on the production deploy
- `yarn transifex:refresh` Refreshes the strings translated on transifex to show them on develop. It can take a couple minutes to show the changes.
- `yarn transifex:purge` This command purges the strings on transifex so we only have the ones present on the code. The strings no used anymore will be deleted.
- `yarn transifex:purge:prod` This command purges the strings on transifex so we only have the ones present on the code. The strings no used anymore will be deleted. This uses the production env.

If the purge is not working correctly try to use it directly from terminal:

`npx txjs-cli push src/ --purge --token=[TX TOKEN HERE] --secret=[TX SECRET HERE]`

### Selecting the translation locale

There is a language switcher component available on the menu. The locale is then retrieved on the App component to set the translation.

### Server-side translation

In some components we need to render items inside `placeholder`, `alt`, `meta` tags, etc for this we can't use the regular client side translations and we have to update them server-side.

- The server side translations have to be requested on every page using `getServerSideProps`and the `getServerSideTranslations` function and set on redux using the `useSetServerSideTranslations` hook. Then we will be able to use them in any component.

- To use them we just have to pick the desired string from the available translations object. `translations['Page title']`

- We use the `withTranslations` HOC to be able to add the `setTranslations` redux action to each page component.

- To be able to use the translations on the Layouts we also pass them directly to them on the `_app.tsx` file.

- As this strings won't be automatically recognised by transifex when we push, there is a json file inside server-side-translations folder: `server-side-translation-content.json` In this file we should add every string that needs to be translated server-side. Then the `push-server-strings.js` file is run with the `yarn transifex:push` on `package.json`.

[More info](https://developers.transifex.com/docs/nextjs#use-getserversideprops-to-load-translations)

### To translate strings

The translation of strings will depend where is the string:

#### Strings inside Components

For strings inside react components or containers its enough to use the useT hook or the T component

```
import { T } from '@transifex/react';

const Component = () => {
  return <T _str='Translated content n.{number}' number={dynamic content inside the curly braces} _comment="Comment for the translators context if needed" />
};
```

#### Strings inside constants

For strings inside constants we will have to create a function that encapsulates that string and is called everytime the locale changes.

```
constant.js

import { t } from '@transifex/native';

export const getTranslation = () => t('Translated content');


component.js
import { getTranslation } from './constant';
import { useLocale } from '@transifex/react';

const Component = () => {
  const locale = useLocale();
  const translation = useMemo(() => getTranslation(), [locale]);

  return translation;
};
```

## CI/CD

When a pull request (PR) is created, a GitHub action runs the tests (`yarn test`).

When the PR is merged or commits are directly pushed to the `develop` branch (not recommended), the tests are also run and the application is deployed to the staging environment: https://staging.resilienceatlas.org/.

When a PR is merged to the `main` branch, the same process is also executed and the application is deployed to the production environment: https://www.resilienceatlas.org/.

It is recommended to mention the Jira task ID either in commits or the branch names so that the deployment information can be directly available in Jira.

## Manual deployment

We are using Capistrano to deploy the application. So, in order to deploy the application, you need to have the following:

- Ruby 3.2.1 (rbenv recommended)

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

When vulnerabilities are detected, a warning message is displayed at the top of the repository. The list of alerts can be found in the [Dependabot alerts page](https://github.com/ConservationInternational/resilienceatlas/security/dependabot).

Here's a step by step guide on how to address vulnerabilities found in production code:

1. Go to the [Dependabot alerts page](https://github.com/ConservationInternational/resilienceatlas/security/dependabot) and locate the front-end vulnerability to address
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
