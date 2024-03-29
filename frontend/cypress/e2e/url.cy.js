describe('URL Management', () => {
  it('A user visits a subdomain and gets redirected to the /map page of that subdomain', () => {
    cy.visit('http://subdomain.localhost:3000/');
    cy.url().should('contain', '/map');
  });

  it('A user visits the resilienceatlas main page without www. it should not be redirected to map', () => {
    cy.visit('http://resilienceatlas.localhost:3000/');
    cy.url().should('not.contain', '/map');
    cy.url().should('eq', 'http://resilienceatlas.localhost:3000/');
  });

  it('A user visits the staging main page without www. it should not be redirected to map', () => {
    cy.visit('http://staging.localhost:3000/');
    cy.url().should('not.contain', '/map');
    cy.url().should('eq', 'http://staging.localhost:3000/');
  });

  it('A user visits an embed map with subdomain. it should not show a 404', () => {
    cy.visit('http://subdomain.localhost:3000/embed/map');
    cy.url().should('contain', '/embed/map');
  });

  it('A user visits some other page in an subdomain', () => {
    cy.request({
      url: 'http://subdomain.localhost:3000/about',
      followRedirect: true, // This will follow the redirection
      failOnStatusCode: false, // This allows the test to continue even if the status code is not 2xx or 3xx
    }).then((response) => {
      expect(response.status).to.eq(404);
    });
  });
});
