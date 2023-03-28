describe('Journeys index page', () => {
  beforeEach(() => {
    cy.visit('/');
  });

  it('should have show the language switcher and show 6 languages', () => {
    cy.get('.language-switcher').should('exist');
    cy.get('.language-switcher').find('li').should('have.length', 6);
  });

  it('should change language url on click', () => {
    cy.get('.language-switcher').trigger('mouseover');
    cy.get('.language-switcher .-childless button').eq(1).click({ force: true });
    cy.url({ decode: true }).should('contain', 'fr');
  });
});
