describe('URL Management', () => {
  it('A user visits a subdomain and gets redirected to the /map page of that subdomain', () => {
    cy.visit('http://subdomain.localhost:3000/');
    cy.url().should('contain', '/map');
  });
});
