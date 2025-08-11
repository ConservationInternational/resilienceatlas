# Resilience Atlas web app

This is the web app powering 
[resilienceatlas.org](http://www.resilienceatlas.org)

## Installation

Requirements:

* Ruby 3.4.4
* Rails 7.2.x
* PostgreSQL

Install global dependencies:

    gem install bundler

Install project dependencies:

    bundle install

## Usage

Before running the application, you need to configure it by copying `.env.sample` to `.env` and setting the appropriate values where needed.

### Create database schema

`bin/rails db:create db:migrate db:seed` to setup the database

### Run the server

`bundle exec rails server` and access the project on `http://localhost:3000`

See the generated api docs (described below) for available API endpoints. The backoffice is accessed at `/admin`.

### Run the tests

`bundle exec rspec`

## Testing with Docker

The project includes a comprehensive Docker test setup that allows you to run both backend and frontend tests in isolated environments.

### Prerequisites

- Docker and Docker Compose installed
- All environment files set up (see setup instructions below)

### Test Environment Setup

Before running tests, ensure your environment files are configured:

**For Unix/Linux/macOS:**
```bash
./docker.sh setup
```

**For Windows:**
```cmd
docker.bat setup
```

This will create `.env` files from the example templates if they don't already exist.

### Running All Tests

To run both backend and frontend tests together:

**For Unix/Linux/macOS:**
```bash
./docker.sh test
```

**For Windows:**
```cmd
docker.bat test
```

**Using Docker Compose directly:**
```bash
docker-compose -f docker-compose.test.yml up --abort-on-container-exit
```

### Running Backend Tests Only

To run only the Ruby/Rails backend tests (RSpec):

**For Unix/Linux/macOS:**
```bash
./docker.sh test-backend
```

**For Windows:**
```cmd
docker.bat test-backend
```

**Using Docker Compose directly:**
```bash
docker-compose -f docker-compose.test.yml run --rm backend-test
```

The backend test setup:
- Creates a PostgreSQL test database with PostGIS extensions
- Runs database migrations and seeding
- Executes RSpec tests (excluding slow system tests)
- Uses isolated test environment with `RAILS_ENV=test`

### Running Frontend Tests Only

To run only the frontend tests (Cypress):

**For Unix/Linux/macOS:**
```bash
./docker.sh test-frontend
```

**For Windows:**
```cmd
docker.bat test-frontend
```

**Using Docker Compose directly:**
```bash
docker-compose -f docker-compose.test.yml run --rm frontend-test
```

The frontend test setup:
- Builds and starts the frontend application
- Waits for backend API to be available
- Runs Cypress end-to-end tests
- Uses Docker-specific Cypress configuration

### Test Environment Details

The test environment (`docker-compose.test.yml`) includes:

- **Database (`db-test`)**: PostgreSQL 15 with PostGIS extensions on port 5433
- **Backend (`backend-test`)**: Rails application in test mode on port 3001
- **Frontend (`frontend-app`)**: Next.js application for testing on port 3000
- **Frontend Tests (`frontend-test`)**: Cypress test runner

### Cleaning Up Test Environment

To stop and clean up test containers and volumes:

**For Unix/Linux/macOS:**
```bash
./docker.sh clean
```

**For Windows:**
```cmd
docker.bat clean
```

### Run rswag to generate API documentation

`SWAGGER_DRY_RUN=0 rake rswag:specs:swaggerize`

Documentation can be found at `/api-docs`.

### Replace snapshot files

On the first run, the `match_snapshot` matcher will always return success and it will store a snapshot file. On the next runs, it will compare the response with the file content.

If you need to replace snapshots, run the specs with:

`REPLACE_SNAPSHOTS=true bundle exec rspec`

If you only need to add, remove or replace data without replacing the whole snapshot:

`CONSERVATIVE_UPDATE_SNAPSHOTS=true bundle exec rspec`

### Run linters

`bin/rails standard`

To fix linter issues

`bin/rails standard:fix`

## Deployment

In `config/deploy` you will find a sample file. Copy `production.rb.sample` to `production.rb` and change it accordingly. Deploy using:
 
```
bundle exec cap production deploy
```

## API Documentation

The Resilience Atlas backend provides a comprehensive REST API for data access, user management, and content delivery. The API follows RESTful conventions and returns JSON responses.

### Base URL and Versioning

- **Base URL**: `/api`
- **Current Version**: `v1` (most endpoints use `/api/v1/`)
- **Content Type**: `application/json`

### Authentication

The API supports multiple authentication methods:

1. **Bearer Token Authentication**
   ```
   Authorization: Bearer <your_token>
   ```

2. **Cookie-based Authentication** (for browser requests)
   ```
   Cookie: _backend_session=<session_value>
   ```

To obtain an authentication token:
```bash
POST /users/authenticate
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password"
}
```

### Interactive API Documentation

Full interactive documentation is available via Swagger UI at `/api-docs` when the server is running. To generate/update the documentation:

```bash
SWAGGER_DRY_RUN=0 rake rswag:specs:swaggerize
```

### Core API Endpoints

#### Data Management

| Endpoint | Method | Description | Auth Required |
|----------|--------|-------------|---------------|
| `/api/layers` | GET | List all layers with filtering | No |
| `/api/layers/{id}/downloads` | GET | Download layer data as ZIP | Optional |
| `/api/layer-groups` | GET | Get layer groups | No |
| `/api/categories` | GET | List categories | No |
| `/api/indicators` | GET | List indicators | No |
| `/api/models` | GET | List models | No |

**Layer Filtering Parameters:**
- `site_scope`: Filter by site scope subdomain
- `locale`: Language (default: 'en')

#### Site & Content Management

| Endpoint | Method | Description | Auth Required |
|----------|--------|-------------|---------------|
| `/api/sites` | GET | List all site scopes | No |
| `/api/site` | GET | Get specific site information | No |
| `/api/homepage` | GET | Get homepage content | No |
| `/api/menu-entries` | GET | Get menu structure | No |
| `/api/static_pages/{slug}` | GET | Get static page content | No |

#### Site Scope Authentication

| Endpoint | Method | Description | Auth Required |
|----------|--------|-------------|---------------|
| `/api/site-scope/authenticate` | POST | Authenticate access to protected site scope | No |
| `/api/site-scope/check-access` | GET | Check authentication status for site scope | No |

**Site Scope Authentication:**
Some site scopes can be password protected. Use these endpoints to handle authentication:

- **Authentication Request Body:**
  ```json
  {
    "site_scope": "subdomain",
    "username": "site_username", 
    "password": "site_password"
  }
  ```

- **Authentication Response:**
  ```json
  {
    "message": "Authentication successful",
    "token": "jwt_token_here",
    "authenticated": true
  }
  ```

- **Using Authentication Token:**
  Include the token in subsequent requests via header:
  ```
  Site-Scope-Token: jwt_token_here
  ```

#### Journey System

| Endpoint | Method | Description | Auth Required |
|----------|--------|-------------|---------------|
| `/api/journeys` | GET | List published journeys | No |
| `/api/journeys/{id}` | GET | Get journey details with steps | No |

**Journey Response includes:**
- Journey metadata (title, subtitle, theme)
- Background images in multiple sizes
- Journey steps with different types (landing, chapter, embed, conclusion)

#### User Management

| Endpoint | Method | Description | Auth Required |
|----------|--------|-------------|---------------|
| `/users/register` | POST | Register new user | No |
| `/users/authenticate` | POST | Login and get token | No |
| `/users/me` | GET | Get current user profile | Yes |
| `/users/me` | PATCH | Update user profile | Yes |

#### Sharing & Interaction

| Endpoint | Method | Description | Auth Required |
|----------|--------|-------------|---------------|
| `/api/share` | POST | Create shareable URL | No |
| `/api/share/{uid}` | GET | Retrieve shared content | No |
| `/api/feedbacks` | POST | Submit user feedback | No |
| `/api/photos` | POST | Upload photos | Yes (Cookie) |
| `/services/oembed` | GET | Get oEmbed data for URLs | No |

#### Administrative Endpoints

| Endpoint | Method | Description | Auth Required |
|----------|--------|-------------|---------------|
| `/api/admin/layers` | GET | List layers (admin view) | Yes (Admin) |
| `/api/admin/layers` | POST | Create new layer | Yes (Admin) |
| `/api/admin/layers/{id}` | GET | Get layer details | Yes (Admin) |
| `/api/admin/layers/{id}` | DELETE | Delete layer | Yes (Admin) |
| `/api/admin/layers/site_scopes` | GET | List site scopes | Yes (Admin) |

**Admin Parameters:**
- `page`: Page number (default: 1)
- `per_page`: Items per page (default: 30)
- `keyword`: Search term for site scopes

### Response Format

#### Success Responses
```json
{
  "data": [...],
  "meta": {
    "total": 100,
    "current_page": 1,
    "total_pages": 10
  }
}
```

#### Error Responses
Following JSON:API specification:
```json
{
  "errors": [
    {
      "status": "404",
      "title": "Record not found"
    }
  ]
}
```

#### Authentication Errors
```json
{
  "success": false,
  "message": "Invalid API Credentials"
}
```

### Example Requests

#### Get Layers for a Site
```bash
curl -X GET "http://localhost:3000/api/layers?site_scope=resilience&locale=en" \
  -H "Accept: application/json"
```

#### Authenticate User
```bash
curl -X POST "http://localhost:3000/users/authenticate" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@example.com",
    "password": "password"
  }'
```

#### Create Share URL
```bash
curl -X POST "http://localhost:3000/api/share" \
  -H "Content-Type: application/json" \
  -d '{
    "body": "{"layers": [1,2,3], "zoom": 5}"
  }'
```

#### Submit Feedback
```bash
curl -X POST "http://localhost:3000/api/feedbacks" \
  -H "Content-Type: application/json" \
  -d '{
    "feedback": {
      "language": "en",
      "feedback_fields_attributes": [
        {
          "feedback_field_type": "single_choice",
          "question": "How satisfied are you?",
          "answer": {"slug": "very-satisfied", "value": "Very Satisfied"}
        }
      ]
    }
  }'
```

#### Authenticate to Protected Site Scope
```bash
curl -X POST "http://localhost:3000/api/site-scope/authenticate" \
  -H "Content-Type: application/json" \
  -d '{
    "site_scope": "protected-site",
    "username": "site_username",
    "password": "site_password"
  }'
```

#### Access Protected Content
```bash
curl -X GET "http://localhost:3000/api/layers?site_scope=protected-site" \
  -H "Site-Scope-Token: your_jwt_token_here" \
  -H "Accept: application/json"
```

### Data Models

#### Layer Object
```json
{
  "id": 123,
  "name": "Population Density",
  "description": "Population density data",
  "slug": "population-density",
  "layer_type": "raster",
  "opacity": 0.8,
  "published": true,
  "analysis_suitable": true,
  "download": true,
  "layer_provider": "gee",
  "zoom_min": 3,
  "zoom_max": 18
}
```

#### Journey Object
```json
{
  "id": 456,
  "title": "Climate Change Impacts",
  "subtitle": "Understanding regional effects",
  "theme": "climate",
  "published": true,
  "background_image": {
    "small": "url_to_small_image",
    "medium": "url_to_medium_image", 
    "original": "url_to_original_image"
  },
  "journey_steps": [...]
}
```

### Error Handling

The API uses standard HTTP status codes:

- `200` - Success
- `201` - Created (for POST requests)
- `400` - Bad Request
- `401` - Unauthorized (including site scope authentication failures)
- `404` - Not Found
- `422` - Unprocessable Entity (validation errors)

#### Site Scope Authentication Errors

When accessing a protected site scope without proper authentication:

```json
{
  "errors": [
    {
      "status": "401",
      "title": "Site scope authentication required",
      "detail": "This site scope requires authentication. Please authenticate first.",
      "meta": {
        "requires_authentication": true,
        "site_scope": "protected-subdomain"
      }
    }
  ]
}
```

### Rate Limiting

Currently, no rate limiting is implemented, but it's recommended for production deployments.

### CORS Configuration

Cross-Origin Resource Sharing (CORS) is configured to allow requests from authorized domains. Check `config/application.rb` for current CORS settings.
