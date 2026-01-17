describe('Journeys index page', () => {
  beforeEach(() => {
    cy.visit('/');
  });

  it('should have show the language switcher and show 6 languages', () => {
    // Use .first() to scope to the desktop language switcher (there's also one in mobile menu)
    cy.get('.language-switcher').first().should('exist');
    cy.get('.language-switcher').first().find('li').should('have.length', 6);
  });
});
