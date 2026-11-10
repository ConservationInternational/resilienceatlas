FROM ghcr.io/maplibre/martin:v1.16.1
USER root
RUN apt-get update -qq && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*
