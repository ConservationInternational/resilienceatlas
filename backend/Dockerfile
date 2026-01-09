# Use the official Ruby image
FROM ruby:3.4-bookworm AS base

# Enable BuildKit inline cache
ARG BUILDKIT_INLINE_CACHE=1

# Configure package manager for better network resilience
RUN echo 'Acquire::Retries "3";' >> /etc/apt/apt.conf.d/80-retries && \
    echo 'Acquire::http::Timeout "60";' >> /etc/apt/apt.conf.d/80-timeout

# Install dependencies with retry logic
RUN for i in {1..3}; do \
      echo "Package installation attempt $i of 3" && \
      apt-get update -qq && apt-get install -y \
        build-essential \
        libpq-dev \
        libgeos-dev \
        libproj-dev \
        libgdal-dev \
        nodejs \
        npm \
        postgresql-client \
        curl \
      && rm -rf /var/lib/apt/lists/* && break || \
      ([ $i -eq 3 ] && echo "❌ Failed to install packages after 3 attempts" && exit 1) || \
      (echo "⚠️ Package installation attempt $i failed, retrying in 10 seconds..." && sleep 10); \
    done

# Configure bundler for better network resilience
RUN bundle config set timeout 60 && \
    bundle config set retry 5

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

# Set environment variables for better network resilience
ENV DEBIAN_FRONTEND=noninteractive
ENV APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1

# Detect architecture and install appropriate browser for system tests
# Chrome is only available for amd64, so we use Chromium for arm64
ARG TARGETARCH
RUN apt-get update -qq && apt-get install -y \
  curl \
  sudo \
  wget \
  gnupg \
  xvfb \
  fonts-liberation \
  libasound2 \
  libatk-bridge2.0-0 \
  libatk1.0-0 \
  libatspi2.0-0 \
  libdrm2 \
  libgtk-3-0 \
  libnspr4 \
  libnss3 \
  libx11-xcb1 \
  libxcomposite1 \
  libxdamage1 \
  libxrandr2 \
  libxss1 \
  libxtst6 \
  && if [ "$(dpkg --print-architecture)" = "amd64" ]; then \
       echo "Installing Google Chrome for amd64..." \
       && wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
       && echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
       && apt-get update -qq \
       && apt-get install -y google-chrome-stable; \
     else \
       echo "Installing Chromium for $(dpkg --print-architecture)..." \
       && apt-get install -y chromium; \
     fi \
  && rm -rf /var/lib/apt/lists/* || \
  echo "Package installation failed, but continuing with existing packages"

# Set environment variable to indicate which browser is installed
ENV CHROME_BIN=/usr/bin/google-chrome
RUN if [ -f /usr/bin/chromium ]; then \
      echo "export CHROME_BIN=/usr/bin/chromium" >> /etc/environment; \
    fi

# Create a non-root user for running Chrome (Chrome refuses to run as root in newer versions)
RUN groupadd -r appuser && useradd -r -g appuser -G audio,video appuser \
  && mkdir -p /home/appuser \
  && chown -R appuser:appuser /home/appuser \
  && echo 'appuser ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# Configure bundler globally (not --local) so config persists when /app is volume-mounted
# This is critical because docker-compose.test.yml mounts ./backend:/app which overrides
# any local .bundle/config created in the image. Global config is stored in /usr/local/bundle/config
RUN bundle config set frozen true && \
    bundle config set with "test development"

# Install test gems with retry logic for network resilience
RUN bash -c 'for i in {1..3}; do \
      echo "Test gems install attempt $i of 3" && \
      bundle install && break || \
      ([ $i -eq 3 ] && echo "❌ Failed to install test gems after 3 attempts" && exit 1) || \
      (echo "⚠️ Test gems install attempt $i failed, retrying in 10 seconds..." && sleep 10); \
    done'

# Copy the application code
COPY . .

# Make scripts executable including Chrome wrapper
RUN chmod +x bin/test bin/rails bin/rake bin/setup bin/spring chrome_wrapper.sh

# Create directories for logs, tmp, uploads, storage, and downloads
RUN mkdir -p log tmp/cache tmp/pids tmp/sockets tmp/storage \
  public/uploads public/uploads/cache public/uploads/store public/storage \
  downloads storage

# Create a proper temp directory for appuser and set all permissions
# CRITICAL: Set ownership and permissions AFTER copying code to ensure correct ownership
RUN mkdir -p /tmp/appuser-tmp /home/appuser/.cache /home/appuser/.config /home/appuser/.local/share/applications \
  && chown -R appuser:appuser /app /tmp/appuser-tmp /home/appuser \
  && chmod -R 755 /app \
  && chmod 755 /tmp/appuser-tmp \
  && chmod -R 755 /home/appuser \
  && chmod -R 775 /app/log /app/tmp /app/public/uploads /app/public/storage /app/downloads /app/storage \
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

# Create directories for logs, tmp, uploads, storage, and downloads
RUN mkdir -p log tmp/cache tmp/pids tmp/sockets tmp/storage \
  public/uploads public/uploads/cache public/uploads/store public/storage \
  downloads storage

# Precompile assets for production (if needed)
RUN bundle exec rake assets:precompile || true

# Expose port 3001
EXPOSE 3001

# Default command
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3001"]
