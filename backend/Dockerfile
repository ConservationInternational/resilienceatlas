# Use the official Ruby image
FROM ruby:3.4.4-bullseye AS base

# Enable BuildKit inline cache
ARG BUILDKIT_INLINE_CACHE=1

# Configure package manager for better network resilience
RUN echo 'Acquire::Retries "3";' >> /etc/apt/apt.conf.d/80-retries && \
    echo 'Acquire::http::Timeout "60";' >> /etc/apt/apt.conf.d/80-timeout

# Install dependencies
RUN apt-get update -qq && apt-get install -y \
  build-essential \
  libpq-dev \
  libgeos-dev \
  libproj-dev \
  libgdal-dev \
  nodejs \
  npm \
  postgresql-client \
  curl \
  && rm -rf /var/lib/apt/lists/*

# Configure bundler for better network resilience
RUN bundle config set timeout 30 && \
    bundle config set retry 3

# Set the working directory
WORKDIR /app

# Copy Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Install Ruby dependencies with retry logic using bash explicitly
RUN bash -c 'for i in {1..3}; do \
      echo "Bundle install attempt $i of 3" && \
      bundle install && break || \
      ([ $i -eq 3 ] && echo "❌ Failed to install gems after 3 attempts" && exit 1) || \
      (echo "⚠️ Bundle install attempt $i failed, retrying in 10 seconds..." && sleep 10); \
    done'

# Test stage
FROM base AS test

# Install additional test dependencies including Chrome for system tests
RUN apt-get update -qq && apt-get install -y \
  wget \
  gnupg \
  xvfb \
  ca-certificates \
  fonts-liberation \
  libasound2 \
  libatk-bridge2.0-0 \
  libdrm2 \
  libgtk-3-0 \
  libnspr4 \
  libnss3 \
  libxss1 \
  libxtst6 \
  xdg-utils \
  sudo \
  && wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/googlechrome-linux-keyring.gpg \
  && sh -c 'echo "deb [arch=amd64 signed-by=/usr/share/keyrings/googlechrome-linux-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list' \
  && apt-get update \
  && apt-get install -y google-chrome-stable \
  && google-chrome --version \
  && which google-chrome \
  && rm -rf /var/lib/apt/lists/*

# Create a non-root user for running Chrome (Chrome refuses to run as root in newer versions)
RUN groupadd -r appuser && useradd -r -g appuser -G audio,video appuser \
  && mkdir -p /home/appuser \
  && chown -R appuser:appuser /home/appuser

# Install test gems
RUN bundle install --with test development

# Copy the application code
COPY . .

# Make scripts executable including Chrome wrapper
RUN chmod +x bin/test bin/rails bin/rake bin/setup bin/spring chrome_wrapper.sh

# Create directories for logs, tmp, and uploads
RUN mkdir -p log tmp/cache tmp/pids tmp/sockets tmp/storage public/uploads public/uploads/cache public/uploads/store

# Create a proper temp directory for appuser and set all permissions
RUN mkdir -p /tmp/appuser-tmp /home/appuser/.cache /home/appuser/.config /home/appuser/.local/share/applications \
  && chown -R appuser:appuser /app /tmp/appuser-tmp /home/appuser \
  && chmod -R 755 /app \
  && chmod 755 /tmp/appuser-tmp \
  && chmod -R 755 /home/appuser \
  && chmod -R 775 /app/log /app/tmp /app/public/uploads \
  && touch /app/log/test.log \
  && chown appuser:appuser /app/log/test.log \
  && chmod 664 /app/log/test.log \
  && chown appuser:appuser /app/Gemfile.lock \
  && chmod 664 /app/Gemfile.lock

# Switch to appuser for running the application
USER appuser

# Ensure tmp directory is writable by appuser after user switch
RUN mkdir -p /app/tmp && chmod -R 755 /app/tmp

# Expose port 3001 for test environment
EXPOSE 3001

# Production stage
FROM base AS production

# Copy the application code
COPY . .

# Create directories for logs, tmp, and uploads
RUN mkdir -p log tmp/cache tmp/pids tmp/sockets tmp/storage public/uploads public/uploads/cache public/uploads/store

# Precompile assets for production (if needed)
RUN bundle exec rake assets:precompile || true

# Expose port 3001
EXPOSE 3001

# Default command
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3001"]
