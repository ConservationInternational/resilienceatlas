# CartoDB API Mocking Implementation

## Problem
Integration tests were failing due to external API calls to CartoDB services. These calls could:
- Timeout or fail due to network issues
- Be rate-limited
- Return inconsistent data
- Cause tests to fail in restricted CI/CD environments

## Solution
Mock all CartoDB API endpoints in Cypress using `cy.intercept()` to eliminate external dependencies.

## Implementation Details

### Files Modified
1. `frontend/cypress/fixtures/cartodb-responses.json` - Mock response data
2. `frontend/cypress/support/commands.js` - Intercept configuration

### Mocked Endpoints

#### 1. Tile Configuration API
**Endpoint:** `https://{account}-cdn.resilienceatlas.org/user/ra/api/v1/map*`
**Purpose:** Returns layergroup ID and CDN URL for tile fetching
**Mock Response:**
```json
{
  "layergroupid": "mock-layergroup-id-12345",
  "cdn_url": {
    "http": "cdn.resilienceatlas.org",
    "https": "cdn.resilienceatlas.org"
  },
  "last_updated": "2024-01-01T00:00:00.000Z"
}
```

#### 2. SQL Bounds API
**Endpoint:** `https://{account}-cdn.resilienceatlas.org/user/ra/api/v2/sql*`
**Purpose:** Returns geographic bounds for zoom-to-fit functionality
**Mock Response:**
```json
{
  "rows": [
    {
      "minx": -180,
      "miny": -90,
      "maxx": 180,
      "maxy": 90
    }
  ],
  "time": 0.001,
  "fields": {
    "minx": { "type": "number" },
    "miny": { "type": "number" },
    "maxx": { "type": "number" },
    "maxy": { "type": "number" }
  },
  "total_rows": 1
}
```

#### 3. Tile Image Requests
**Endpoint:** `https://cdn.resilienceatlas.org/ra/api/v1/map/*/*.png`
**Purpose:** Tile images displayed on the map
**Mock Response:** 1x1 transparent PNG (base64 encoded)
- Prevents 404 errors for missing tiles
- Allows map to render without visual artifacts

#### 4. UTF Grid Requests
**Endpoint:** `https://cdn.resilienceatlas.org/ra/api/v1/map/*/*.grid.json`
**Purpose:** Interactivity data for layer popups/tooltips
**Mock Response:**
```json
{
  "grid": ["                                "],
  "keys": [],
  "data": {}
}
```

## Usage

All tests that call `cy.interceptAllRequests()` automatically get CartoDB mocking. No changes needed to individual test files.

```javascript
describe('Map tests', () => {
  beforeEach(() => {
    cy.interceptAllRequests(); // CartoDB mocking enabled automatically
    cy.visit('/map');
  });
  
  it('should load CartoDB layers', () => {
    // Test code here - all CartoDB calls are mocked
  });
});
```

## Affected Tests

Tests that interact with CartoDB layers now run reliably:
- `cypress/e2e/map.cy.js` - Map page functionality
- `cypress/e2e/layer-manager.cy.js` - Layer management
- `cypress/e2e/layer-error-handling.cy.js` - Error handling
- `cypress/e2e/analysis-panel.cy.js` - Analysis features

## Benefits

1. **Reliability:** Tests don't fail due to external service issues
2. **Speed:** No network latency from external API calls  
3. **Consistency:** Same responses every test run
4. **Isolation:** No external rate limits or quotas
5. **CI/CD:** Works in restricted network environments

## CartoDB Layer Flow

```
1. Component requests layer configuration
   ↓
2. Mock returns layergroup ID + CDN URL
   ↓
3. Leaflet requests tile images using URLs from step 2
   ↓
4. Mock returns transparent PNG tiles
   ↓
5. If interactivity enabled, Leaflet requests UTF Grid
   ↓
6. Mock returns empty grid data
   ↓
7. Layer renders successfully with mocked data
```

## Troubleshooting

If tests still fail after applying these changes:

1. **Check intercept URLs match actual requests:**
   - Open browser console during test
   - Look for network requests
   - Verify URL patterns match intercepts

2. **Verify interceptAllRequests is called:**
   - Should be in `beforeEach` or test setup
   - Check test logs for "Intercepting requests"

3. **Test mock responses:**
   ```javascript
   cy.interceptAllRequests();
   cy.visit('/map');
   cy.wait('@cartodbTileRequest').its('response.statusCode').should('eq', 200);
   ```

## Future Enhancements

If more sophisticated mocking is needed:

1. **Dynamic responses based on layer ID:**
   ```javascript
   cy.intercept('**/map*', (req) => {
     // Parse layer config from request
     // Return specific mock for that layer
   });
   ```

2. **Realistic tile data for visual testing:**
   - Generate tiles with actual geographic features
   - Use static tile sets for specific test scenarios

3. **Error scenario testing:**
   - Mock 4xx/5xx responses to test error handling
   - Simulate timeouts or network failures
