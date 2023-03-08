describe('Journeys page', () => {
  beforeEach(() => {
    cy.intercept('GET', '/api/journeys').as('journeysRequest');
    cy.visit('/journeys');
  });

  it('should have a title', () => {
    cy.get('.m-journey__title h1')
      .first()
      .should('contain', 'Discover Journeys');
  });

  it('should have same length than journeys in the API', () => {
    cy.wait('@journeysRequest').then(({ response }) => {
      cy.wrap(response.statusCode).should('be.equal', 200);
      cy.get('.m-journey__gridelement').should(
        'have.length',
        response.body.length,
      );
    });
  });

  it('should show the journeys content according the API', () => {
    cy.wait('@journeysRequest').then(({ response }) => {
      cy.wrap(response.statusCode).should('be.equal', 200);
      cy.get('.m-journey__gridelement').each(($el, index) => {
        cy.wrap($el)
          .find('h2')
          .should('contain', response.body[index].title)
          .find('a')
          .should('have.attr', 'href')
          .should('include', `/journeys/${response.body[index].id}`);
        cy.wrap($el)
          .find('.btn')
          .should('contain', 'Learn more')
          .should('have.attr', 'href')
          .should('include', `/journeys/${response.body[index].id}`);
      });
    });
  });
});
