# Docker Bake configuration for coordinated multi-service builds
# This enables more efficient caching across frontend and backend services

variable "CACHE_FROM" {
  default = ""
}

variable "CACHE_TO" {
  default = ""
}

variable "PLATFORM" {
  default = "linux/amd64"
}

variable "REGISTRY" {
  default = "ghcr.io/conservationinternational/resilienceatlas"
}

# Base group for all services
group "default" {
  targets = ["backend-test", "frontend-test"]
}

# Backend test target
target "backend-test" {
  context = "./backend"
  dockerfile = "Dockerfile"
  target = "test"
  tags = ["resilienceatlas-backend:test"]
  platforms = [PLATFORM]
  cache-from = [
    "type=local,src=/tmp/.buildx-cache",
    "type=gha",
    "${CACHE_FROM}"
  ]
  cache-to = [
    "type=local,dest=/tmp/.buildx-cache-new,mode=max",
    "type=gha,mode=max",
    "${CACHE_TO}"
  ]
  args = {
    BUILDKIT_INLINE_CACHE = "1"
  }
}

# Frontend test target
target "frontend-test" {
  context = "./frontend"
  dockerfile = "Dockerfile"
  target = "test"
  tags = ["resilienceatlas-frontend:test"]
  platforms = [PLATFORM]
  cache-from = [
    "type=local,src=/tmp/.buildx-cache",
    "type=gha",
    "${CACHE_FROM}"
  ]
  cache-to = [
    "type=local,dest=/tmp/.buildx-cache-new,mode=max",
    "type=gha,mode=max",
    "${CACHE_TO}"
  ]
  args = {
    BUILDKIT_INLINE_CACHE = "1"
    CYPRESS_INSTALL_BINARY = "0"
    NEXT_PUBLIC_API_HOST = "http://localhost:3001"
    NEXT_PUBLIC_GOOGLE_ANALYTICS = "GA_TEST_ID"
    NEXT_PUBLIC_TRANSIFEX_TOKEN = "test_token"
    NEXT_PUBLIC_TRANSIFEX_SECRET = "test_secret"
    NEXT_PUBLIC_GOOGLE_API_KEY = "test_api_key"
  }
}

# Integration test group for coordinated builds
group "integration" {
  targets = ["backend-integration", "frontend-integration"]
}

# Backend integration target
target "backend-integration" {
  inherits = ["backend-test"]
  tags = ["resilienceatlas-backend:integration-test"]
}

# Frontend integration target  
target "frontend-integration" {
  inherits = ["frontend-test"]
  tags = ["resilienceatlas-frontend:integration-test"]
  args = {
    BUILDKIT_INLINE_CACHE = "1"
    CYPRESS_INSTALL_BINARY = "0"
    NEXT_PUBLIC_API_HOST = "http://backend-test:3001"
    NEXT_PUBLIC_GOOGLE_ANALYTICS = "GA_INTEGRATION_TEST_ID"
    NEXT_PUBLIC_TRANSIFEX_TOKEN = "integration_test_token"
    NEXT_PUBLIC_TRANSIFEX_SECRET = "integration_test_secret"
    NEXT_PUBLIC_GOOGLE_API_KEY = "integration_test_api_key"
  }
}