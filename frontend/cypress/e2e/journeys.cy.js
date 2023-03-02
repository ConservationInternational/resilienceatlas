describe('Journeys page', () => {
  beforeEach(() => {
    cy.visit('/journeys');
  });

  it('should have a title', () => {
    cy.get('.m-journey__title h1')
      .first()
      .should('contain', 'Discover Journeys');
  });

  it('should there be a list of 5 journeys', () => {
    cy.get('.m-journey__gridelement').should('have.length', 5);
  });

  it('should Ethiopia journey navigates to its correspondent page', () => {
    cy.get('.m-journey__gridelement')
      .first()
      .find('h2 a[href="/journeys/1"]')
      .should('contain', 'ETHIOPIA');
    cy.get('.m-journey__gridelement')
      .first()
      .find('.btn[href="/journeys/1"]')
      .should('contain', 'Learn more');
  });

  it('should India journey navigates to its correspondent page', () => {
    cy.get('.m-journey__gridelement')
      .eq(2)
      .find('h2 a[href="/journeys/3"]')
      .should('contain', 'INDIA');
    cy.get('.m-journey__gridelement')
      .eq(2)
      .find('.btn[href="/journeys/3"]')
      .should('contain', 'Learn more');
  });

  it('should Africa journey navigates to its correspondent page', () => {
    cy.get('.m-journey__gridelement')
      .eq(3)
      .find('h2 a[href="/journeys/4"]')
      .should('contain', 'AFRICA');
    cy.get('.m-journey__gridelement')
      .eq(3)
      .find('.btn[href="/journeys/4"]')
      .should('contain', 'Learn more');
  });

  it('should Madagascar journey navigates to its correspondent page', () => {
    cy.get('.m-journey__gridelement')
      .eq(4)
      .find('h2 a[href="/journeys/5"]')
      .should('contain', 'MADAGASCAR');
    cy.get('.m-journey__gridelement')
      .eq(4)
      .find('.btn[href="/journeys/5"]')
      .should('contain', 'Learn more');
  });
});
