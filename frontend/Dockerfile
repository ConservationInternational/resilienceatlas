FROM node:14-bullseye

ARG REACT_APP_API_HOST

ENV NODE_ENV production
ENV REACT_APP_API_HOST $REACT_APP_API_HOST
ENV REACT_APP_API_PROD $REACT_APP_API_PROD
ENV NODE_PATH src
ENV SASS_PATH node_modules:src/views/styles/

RUN apt update -y && apt upgrade -y

WORKDIR /app

COPY package.json yarn.lock ./

RUN yarn install --production=false

COPY src ./src
COPY cypress ./cypress
COPY public ./public
COPY server.js cypress.config.js config-overrides.js ./

RUN yarn build

EXPOSE 3000

CMD ["node", "server"]