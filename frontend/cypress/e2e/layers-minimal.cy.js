// Only run this test for the next layers
const data = [{ id: 79 }, { id: 2040 }, { id: 1608 }, { id: 1347 }, { id: 504 }];

const disableRequestCache = (req) => {
  req.on('before:response', (res) => {
    // force all API responses to not be cached
    res.headers['cache-control'] = 'no-store';
  });
};

describe('Layers', () => {
  beforeEach(() => {
    cy.intercept({ method: 'GET', url: '/api/site', middleware: true }, disableRequestCache, {
      fixture: 'site.json',
    }).as('siteAPIRequest');

    cy.intercept(
      { method: 'GET', url: '/api/layer-groups', middleware: true },
      disableRequestCache,
      { fixture: 'layer-groups.json' },
    ).as('layerGroupsAPIRequest');

    // Overriding the layers API request to use a fixture
    // Source: https://www.resilienceatlas.org/api/layers
    // Date: 2023-03-31
    cy.intercept(
      {
        method: 'GET',
        url: '/api/layers*',
        middleware: true,
      },
      disableRequestCache,
      // Un-comment next line and remove `cypress-visual-screenshots/baseline` folder contents
      // to redo the baseline screenshots
      // { fixture: 'layers-original.prod.json' },
    ).as('layersAPIRequest');
  });

  if (Cypress.env('RUN_LAYERS_TESTS')) {
    data.forEach((layerData) => {
      it(`layer ID: ${layerData.id} renderization should match with original one`, () => {
        cy.log(`Layer: ${layerData.id}`);

        // Checking one tile request to see if the layer is rendered
        cy.intercept('/user/ra/api/v1/map/**/3/6/4.png', { requestTimeout: 90000 }).as(
          'rasterTileRequests',
        );

        // Using embed view to load the layers
        cy.visit(`/embed/map?layers=[{"id":${layerData.id},"opacity":1,"order":null}]&zoom=3`);
        cy.wait(['@siteAPIRequest', '@layerGroupsAPIRequest', '@layersAPIRequest']);

        cy.wait('@rasterTileRequests').then((interception) => {
          if (interception.response.statusCode === 200) {
            // TODO: find a way to wait for the layer to be rendered
            // time to render the layer after being requested
            cy.wait(3000);
            cy.compareSnapshot(`layer-original-${layerData.id}`, 0.2);
          }
        });
      });
    });
  }
});
