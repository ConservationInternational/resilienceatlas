describe('Journeys detail page', () => {
  beforeEach(() => {
    cy.intercept('GET', '/api/journeys').as('journeysRequest');
    cy.intercept('GET', '/api/journeys/*').as('journeyDetailRequest');
    cy.visit('/journeys');

    // Navigate to the first journey detail
    cy.wait('@journeysRequest').then(({ response }) => {
      cy.wrap(response.statusCode).should('be.equal', 200);
      cy.get('.m-journey__gridelement')
        .first()
        .find('.btn')
        .click();
    });
  });

  it('should have a title according the API response', () => {
    cy.wait('@journeyDetailRequest').then(({ response }) => {
      cy.wrap(response.statusCode).should('be.equal', 200);
      cy.url().should('include', `/journeys/${response.body[0].id}/step/1`);
      cy.get('.l-journey__intro .intro > h1')
        .first()
        .contains(response.body[0].title, { matchCase: false });
      cy.get('.l-journey__intro .intro > h3')
        .first()
        .contains(response.body[0].subtitle);
    });
  });
});
