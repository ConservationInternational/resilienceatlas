# Use the official Ruby image
FROM ruby:3.4.4-bullseye AS base

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

# Set the working directory
WORKDIR /app

# Copy Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Install Ruby dependencies
RUN bundle install

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

# Create directories for logs and tmp
RUN mkdir -p log tmp/cache tmp/pids tmp/sockets tmp/storage

# Create a proper temp directory for appuser (not world-writable) and fix permissions
RUN mkdir -p /tmp/appuser-tmp /home/appuser/.cache /home/appuser/.config /home/appuser/.local/share/applications \
  && chown -R appuser:appuser /app /tmp/appuser-tmp /home/appuser \
  && chmod -R 755 /app \
  && chmod 755 /tmp/appuser-tmp \
  && chmod -R 755 /home/appuser

# Switch to appuser for running the application
USER appuser

# Expose port 3001 for test environment
EXPOSE 3001

# Production stage
FROM base AS production

# Copy the application code
COPY . .

# Create directories for logs and tmp
RUN mkdir -p log tmp/cache tmp/pids tmp/sockets tmp/storage

# Precompile assets for production (if needed)
RUN bundle exec rake assets:precompile || true

# Expose port 3001
EXPOSE 3001

# Default command
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3001"]
