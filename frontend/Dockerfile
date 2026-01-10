# Base dependencies stage
FROM node:24.0.0-bullseye AS base

# Enable BuildKit inline cache
ARG BUILDKIT_INLINE_CACHE=1

RUN mkdir -p ~/.ssh && touch ~/.ssh/known_hosts

# Enhanced git configuration for SSH dependency handling and network resilience
RUN git config --global url.https://github.com/.insteadOf ssh://git@github.com/ && \
    git config --global url.https://github.com/.insteadOf git@github.com: && \
    git config --global url.https://github.com/.insteadOf git+ssh://git@github.com/ && \
    git config --global http.postBuffer 524288000 && \
    git config --global http.timeout 30

# Configure npm for better network resilience
RUN npm config set registry https://registry.npmjs.org/ && \
    npm config set fetch-timeout 600000 && \
    npm config set fetch-retry-mintimeout 10000 && \
    npm config set fetch-retry-maxtimeout 60000 && \
    npm config set fetch-retries 5

# Set Cypress environment variables for controlled downloads 
ENV CYPRESS_CACHE_FOLDER="/tmp/cypress-cache"

WORKDIR /app
COPY package.json package-lock.json .npmrc ./

# Install dependencies only when needed
FROM base AS deps
# Install production dependencies with npm cache mount for faster builds
RUN --mount=type=cache,target=/root/.npm \
    npm ci --only=production --legacy-peer-deps --no-audit --no-fund \
  && echo "✅ Production dependencies installed successfully"

# Development/Test dependencies
FROM base AS dev-deps
# Skip Cypress binary download during npm install - it will be downloaded on first use
ENV CYPRESS_INSTALL_BINARY=0

# Install all dependencies with npm cache mount for faster builds
RUN --mount=type=cache,target=/root/.npm \
    npm ci --legacy-peer-deps --no-audit --no-fund \
  && echo "🔍 Verifying node_modules exists..." \
  && ls -la /app/node_modules/ | head -5 \
  && echo "✅ node_modules verified"

# Development stage - for docker compose watch
FROM node:24.0.0-bullseye AS development
WORKDIR /app

# Install curl for health checks
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Enhanced git configuration for SSH dependency handling and network resilience
RUN git config --global url.https://github.com/.insteadOf ssh://git@github.com/ && \
    git config --global url.https://github.com/.insteadOf git@github.com: && \
    git config --global url.https://github.com/.insteadOf git+ssh://git@github.com/ && \
    git config --global http.postBuffer 524288000 && \
    git config --global http.timeout 30

# Configure npm for better network resilience
RUN npm config set registry https://registry.npmjs.org/ && \
    npm config set fetch-timeout 600000 && \
    npm config set fetch-retry-mintimeout 10000 && \
    npm config set fetch-retry-maxtimeout 60000 && \
    npm config set fetch-retries 5

# Copy dependencies from dev-deps stage
COPY --from=dev-deps /app/node_modules ./node_modules
COPY package.json .npmrc ./

# Set environment variables for development
ENV NODE_ENV=development
ENV NEXT_TELEMETRY_DISABLED=1
ENV CYPRESS_INSTALL_BINARY=0
ENV CYPRESS_RUN_BINARY=/dev/null

# Copy application source
COPY . .

EXPOSE 3000
ENV PORT=3000

# Default command for development
CMD ["npm", "run", "dev"]

# Test stage
FROM node:24.0.0-bullseye AS test
WORKDIR /app

# Install curl for health checks
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Copy dependencies
COPY --from=dev-deps /app/node_modules ./node_modules
COPY package.json .npmrc ./

# Verify node_modules was copied successfully
RUN echo "🔍 Verifying node_modules in test stage..." \
  && ls -la /app/node_modules/ | head -5 \
  && echo "✅ node_modules verified in test stage"

# Install Cypress binary (was skipped during npm install for faster build)
ENV CYPRESS_CACHE_FOLDER="/tmp/cypress-cache"
RUN --mount=type=cache,target=/tmp/cypress-cache \
    npx cypress install \
  && echo "✅ Cypress binary installed"

# Copy application source
COPY . .

# Make scripts executable
RUN chmod +x bin/test

# Set build arguments with default values
ARG NEXT_PUBLIC_API_HOST=http://localhost:3001
ARG NEXT_PUBLIC_GOOGLE_ANALYTICS=GA_TEST_ID
ARG NEXT_PUBLIC_TRANSIFEX_TOKEN=test_token
ARG NEXT_PUBLIC_TRANSIFEX_SECRET=test_secret
ARG NEXT_PUBLIC_GOOGLE_API_KEY=test_api_key

# Set environment variables
ENV NEXT_PUBLIC_API_HOST=$NEXT_PUBLIC_API_HOST
ENV NEXT_PUBLIC_GOOGLE_ANALYTICS=$NEXT_PUBLIC_GOOGLE_ANALYTICS
ENV NEXT_PUBLIC_TRANSIFEX_TOKEN=$NEXT_PUBLIC_TRANSIFEX_TOKEN
ENV NEXT_PUBLIC_TRANSIFEX_SECRET=$NEXT_PUBLIC_TRANSIFEX_SECRET
ENV NEXT_PUBLIC_GOOGLE_API_KEY=$NEXT_PUBLIC_GOOGLE_API_KEY
ENV NODE_ENV=test
ENV NEXT_TELEMETRY_DISABLED=1

EXPOSE 3000
ENV PORT=3000

# Default command for test stage
CMD ["npm", "run", "dev"]

# Rebuild the source code only when needed
FROM node:24.0.0-bullseye AS builder
WORKDIR /app

# Set build arguments
ARG NEXT_PUBLIC_API_HOST
ARG NEXT_PUBLIC_GOOGLE_ANALYTICS
ARG NEXT_PUBLIC_TRANSIFEX_TOKEN
ARG NEXT_PUBLIC_TRANSIFEX_SECRET
ARG NEXT_PUBLIC_GOOGLE_API_KEY

# Set environment variables
ENV NEXT_PUBLIC_API_HOST=$NEXT_PUBLIC_API_HOST
ENV NEXT_PUBLIC_GOOGLE_ANALYTICS=$NEXT_PUBLIC_GOOGLE_ANALYTICS
ENV NEXT_PUBLIC_TRANSIFEX_TOKEN=$NEXT_PUBLIC_TRANSIFEX_TOKEN
ENV NEXT_PUBLIC_TRANSIFEX_SECRET=$NEXT_PUBLIC_TRANSIFEX_SECRET
ENV NEXT_PUBLIC_GOOGLE_API_KEY=$NEXT_PUBLIC_GOOGLE_API_KEY

COPY . .
COPY --from=deps /app/node_modules ./node_modules

# Next.js collects completely anonymous telemetry data about general usage.
# Learn more here: https://nextjs.org/telemetry
# Uncomment the following line in case you want to disable telemetry during the build.
ENV NEXT_TELEMETRY_DISABLED=1

RUN npm run build

# Production image, copy all the files and run next
FROM node:24.0.0-bullseye AS production
WORKDIR /app

ENV NODE_ENV=production
# Uncomment the following line in case you want to disable telemetry during runtime.
ENV NEXT_TELEMETRY_DISABLED=1

# Install curl for health checks and tini for proper signal handling
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    tini \
    && rm -rf /var/lib/apt/lists/*

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# You only need to copy next.config.js if you are NOT using the default configuration
COPY --from=builder /app/next.config.js ./
# Copy locales config for i18n
COPY --from=builder /app/locales.config.json ./
COPY --from=builder /app/public ./public
COPY --from=builder /app/package.json ./package.json

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

# Use tini as init system for proper signal handling in containers
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["node", "server.js"]
