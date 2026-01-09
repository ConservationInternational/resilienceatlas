# Integration Tests

This directory contains integration tests that verify the frontend and backend can communicate successfully.

## Purpose

These tests ensure that:
- The backend API is accessible and responding
- The frontend is accessible 
- Critical API endpoints are working
- Frontend and backend can communicate properly

## Running the Tests

### Local Development
```bash
cd integration-tests
npm install
npm test
```

### Docker Environment
```bash
cd integration-tests
npm install
npm run test:docker
```

### With Custom URLs
```bash
FRONTEND_URL=http://localhost:3000 BACKEND_URL=http://localhost:3001 node test-integration.js
```

## Test Coverage

The integration tests cover:
- Backend health check endpoint (`/api/health`)
- Frontend accessibility test
- Critical API endpoints (`/api/layers`, `/api/indicators`)
- Cross-origin API request simulation

## Adding New Tests

To add new integration tests, modify `test-integration.js` and add new test functions or endpoints to verify.