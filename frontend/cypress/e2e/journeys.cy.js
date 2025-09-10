describe('Journeys index page', () => {
  beforeEach(() => {
    cy.interceptAllRequests();
    cy.visit('/journeys');
    cy.wait('@siteRequest');
  });

  it('should have a title', () => {
    cy.get('.m-journey__title h1').first().should('contain', 'Discover Journeys');
  });

  it('should have same length than journeys in the API', () => {
    cy.wait('@journeyListRequest').then(({ response }) => {
      cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);
      cy.get('.m-journey__gridelement').should('have.length', response.body.data.length);
    });
  });

  it('should show the journeys content according the API', () => {
    cy.wait('@journeyListRequest').then(({ response }) => {
      cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);
      cy.log(response);
      const journeys = response.body?.data || [];
      
      if (journeys.length === 0) return cy.skip();
      cy.get('.m-journey__gridelement').each(($el, index) => {
        const journey = journeys[index] || {};
        cy.wrap($el)
          .find('h2')
          .should('contain', journey.attributes?.title)
          .find('a')
          .should('have.attr', 'href')
          .should('include', `/journeys/${journey.id}`);
        cy.wrap($el)
          .find('.btn')
          .should('contain', 'Learn more')
          .should('have.attr', 'href')
          .should('include', `/journeys/${journey.id}`);
      });
    });
  });
});
