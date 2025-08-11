# Base dependencies stage
FROM node:22.11.0-bullseye AS base
RUN mkdir -p ~/.ssh && touch ~/.ssh/known_hosts
# Configure git to use HTTPS instead of SSH for all git operations
RUN git config --global url.https://github.com/.insteadOf ssh://git@github.com/ && \
    git config --global url.https://github.com/.insteadOf git@github.com: && \
    git config --global url.https://github.com/.insteadOf git+ssh://git@github.com/
WORKDIR /app
COPY package.json package-lock.json .npmrc ./

# Install dependencies only when needed
FROM base AS deps
# Retry npm install up to 3 times for network resilience
RUN for i in {1..3}; do \
      echo "npm install attempt $i of 3" && \
      timeout 300 npm ci --only=production --legacy-peer-deps --no-audit --no-fund && \
      echo "✅ Production dependencies installed successfully" && \
      break || \
      ([ $i -eq 3 ] && echo "❌ Failed to install production dependencies after 3 attempts" && exit 1) || \
      (echo "⚠️ npm install attempt $i failed, retrying in 10 seconds..." && sleep 10); \
    done

# Development/Test dependencies
FROM base AS dev-deps
# Retry npm install up to 3 times for network resilience
RUN for i in {1..3}; do \
      echo "npm install attempt $i of 3" && \
      timeout 300 npm ci --legacy-peer-deps --no-audit --no-fund && \
      echo "✅ All dependencies installed successfully" && \
      break || \
      ([ $i -eq 3 ] && echo "❌ Failed to install dependencies after 3 attempts" && exit 1) || \
      (echo "⚠️ npm install attempt $i failed, retrying in 10 seconds..." && sleep 10); \
    done

# Test stage
FROM node:22.11.0-bullseye AS test
WORKDIR /app

# Install curl for health checks
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Copy dependencies
COPY --from=dev-deps /app/node_modules ./node_modules
COPY package.json package-lock.json .npmrc ./

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
FROM node:22.11.0-bullseye AS builder
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
FROM node:22.11.0-bullseye AS production
WORKDIR /app

ENV NODE_ENV=production
# Uncomment the following line in case you want to disable telemetry during runtime.
ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# You only need to copy next.config.js if you are NOT using the default configuration
COPY --from=builder /app/next.config.js ./
COPY --from=builder /app/public ./public
COPY --from=builder /app/package.json ./package.json

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT=3000

CMD ["node", "server.js"]
