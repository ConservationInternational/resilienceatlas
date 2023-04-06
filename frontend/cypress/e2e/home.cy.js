// TODO Simao Home | Update e2e tests to work with API data, not only mocked data

describe('Home page', () => {
  beforeEach(() => {
    cy.visit('/');
  });

  it('should have a welcome message', () => {
    cy.get('.m-home-intro').find('h3').should('contain', 'WELCOME TO');
    cy.get('.m-home-intro').find('h2').should('contain', 'RESILIENCE ATLAS');
  });

  it('in journeys section should have a link to the journeys page', () => {
    cy.get('.m-home-journeys__bottom')
      .find('a.btn-primary[href="/journeys"]')
      .should('contain', 'More journeys')
      .click();
    cy.location('pathname').should('eq', '/journeys');
  });

  it('in explore section should have a link to the map page', () => {
    cy.get('.m-home-section')
      .eq(0)
      .find('a.btn-primary[href="/map"]')
      .should('contain', 'Go to the map')
      .click();
    cy.location('pathname').should('eq', '/map');
  });

  it('in about section should have a link to the about page', () => {
    cy.get('.m-home-section')
      .eq(1)
      .find('a.btn-primary[href="/about"]')
      .should('contain', 'Learn more')
      .click();
    cy.location('pathname').should('eq', '/about');
  });

  it('in about section should have a link to the map page', () => {
    cy.get('.m-home-section')
      .eq(2)
      .find('a.btn-primary[href="/map"]')
      .should('contain', 'Analysing the data')
      .click();
    cy.location('pathname').should('eq', '/map');
  });
});
