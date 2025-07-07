# Use the official Ruby image
FROM ruby:3.4.4-bullseye as base

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
FROM base as test

# Install additional test dependencies including Chrome for system tests
RUN apt-get update -qq && apt-get install -y \
  wget \
  gnupg \
  && wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
  && sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list' \
  && apt-get update \
  && apt-get install -y google-chrome-stable \
  && rm -rf /var/lib/apt/lists/*

# Install test gems
RUN bundle install --with test development

# Copy the application code
COPY . .

# Create directories for logs and tmp
RUN mkdir -p log tmp/cache tmp/pids tmp/sockets tmp/storage

# Expose port 3001 for test environment
EXPOSE 3001

# Production stage
FROM base as production

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
