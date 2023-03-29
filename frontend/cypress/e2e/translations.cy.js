describe('Journeys index page', () => {
  beforeEach(() => {
    cy.visit('/');
  });

  it('should have show the language switcher and show 6 languages', () => {
    cy.get('.language-switcher').should('exist');
    cy.get('.language-switcher').find('li').should('have.length', 6);
  });

  it('should show the language string for the selected language on the selector', () => {
    cy.visit('/?lang=fr');
    cy.get('.language-switcher .nav-item').should('contain', 'Français');
  });
});
