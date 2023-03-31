import layersRaw from '../fixtures/layers-original.prod.json';

const { data } = layersRaw;

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
      {
        fixture: 'layer-groups.json',
      },
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
      { fixture: 'layers-original.prod.json' },
    ).as('layersAPIRequest');
  });

  if (Cypress.env('RUN_LAYERS_TESTS')) {
    data.slice(0, 10).forEach((layerData) => {
      it(`layer ID: ${layerData.id} should render in a map`, () => {
        cy.log(`Layer: ${layerData.id}`);

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
            cy.screenshot(`layer-original-${layerData.id}`, { overwrite: true });
          }
        });
      });
    });

    // it('load layers from fixture', () => {
    //   cy.fixture('layers-original.prod.json').then((layers) => {
    //     const { data } = layers;
    //     cy.log(`Loaded ${data.length} layers`);
    //     data.slice(0, 10).forEach((layer) => {
    //       cy.log(`Layer: ${layer.id}`);

    //       // Intercepts
    //       cy.intercept('/user/ra/api/v1/map/**/3/6/4.png', { requestTimeout: 90000 }).as(
    //         'rasterTileRequests',
    //       );
    //       // if (layer.attributes.layer_provider === 'cartodb') {
    //       //   cy.intercept('/user/ra/api/v1/map/**/3/6/4.grid.json', { requestTimeout: 90000 }).as(
    //       //     'cartoTileRequests',
    //       //   );
    //       // }

    //       // if (layer.attributes.layer_provider === 'raster') {
    //       //   cy.intercept('/user/ra/api/v1/map/**/3/6/4.png', { requestTimeout: 90000 }).as(
    //       //     'rasterTileRequests',
    //       //   );
    //       // }

    //       // Using embed view to load the layers
    //       cy.visit(`/embed/map?layers=[{"id":${layer.id},"opacity":1,"order":null}]&zoom=3`);
    //       cy.wait(['@siteAPIRequest', '@layerGroupsAPIRequest', '@layersAPIRequest']);

    //       // Intercepts the layers requests depending on the layer provider
    //       // if (layer.attributes.layer_provider === 'cartodb') {
    //       //   cy.wait('@cartoTileRequests').then((interception) => {
    //       //     if (interception.response.statusCode === 200) {
    //       //       // TODO: find a way to wait for the layer to be rendered
    //       //       // time to render the layer after being requested
    //       //       cy.wait(3000);
    //       //       cy.screenshot(`layer-original-${layer.id}`, { overwrite: true });
    //       //     }
    //       //   });
    //       // }
    //       // if (layer.attributes.layer_provider === 'raster') {
    //       //   cy.wait('@rasterTileRequests').then((interception) => {
    //       //     if (interception.response.statusCode === 200) {
    //       //       // TODO: find a way to wait for the layer to be rendered
    //       //       // time to render the layer after being requested
    //       //       cy.wait(3000);
    //       //       cy.screenshot(`layer-original-${layer.id}`, { overwrite: true });
    //       //     }
    //       //   });
    //       // }
    //       cy.wait('@rasterTileRequests').then((interception) => {
    //         if (interception.response.statusCode === 200) {
    //           // TODO: find a way to wait for the layer to be rendered
    //           // time to render the layer after being requested
    //           cy.wait(3000);
    //           cy.screenshot(`layer-original-${layer.id}`, { overwrite: true });
    //         }
    //       });
    //     });
    //   });
    // });
  }
});
