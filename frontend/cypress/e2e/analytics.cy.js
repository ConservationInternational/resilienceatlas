describe('Main menu', () => {
  beforeEach(() => {
    cy.clearCookies();
    cy.visit('/');
  });

  it('should show the privacy banner', () => {
    cy.get('.m-privacy-banner');
  });

  it('should remove the privacy banner when we click in accept', () => {
    cy.get('.m-privacy-banner').find('button[data-test-id="accept"]').click();
    cy.get('.m-privacy-banner').should('not.exist');
  });

  it('should remove the privacy banner when we click in refuse', () => {
    cy.get('.m-privacy-banner').find('button[data-test-id="refuse"]').click();
    cy.get('.m-privacy-banner').should('not.exist');
  });

  it('should add the ga scripts when we click in accept', () => {
    cy.get('.m-privacy-banner').find('button[data-test-id="accept"]').click();
    cy.get('#ga-script').should('exist');
    cy.get('#gtag-script').should('exist');
  });

  it('should not add the ga scripts when we click in refuse', () => {
    cy.get('.m-privacy-banner').find('button[data-test-id="refuse"]').click();
    cy.get('#ga-script').should('not.exist');
    cy.get('#gtag-script').should('not.exist');
  });
});
