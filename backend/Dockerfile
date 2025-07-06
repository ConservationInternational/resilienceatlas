# Use the official Ruby image
FROM ruby:3.4.4-bullseye

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
  # Install Chrome for system tests
  wget \
  gnupg \
  && wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
  && sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list' \
  && apt-get update \
  && apt-get install -y google-chrome-stable \
  && rm -rf /var/lib/apt/lists/*

# Set the working directory
WORKDIR /app

# Copy Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Install Ruby dependencies
RUN bundle install

# Copy the application code
COPY . .

# Create directories for logs and tmp
RUN mkdir -p log tmp/cache tmp/pids tmp/sockets tmp/storage

# Expose port 3000
EXPOSE 3000

# Default command
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
