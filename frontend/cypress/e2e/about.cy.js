describe('About page', () => {
  beforeEach(() => {
    cy.visit('/about');
  });

  it('should have a title', () => {
    cy.get('h1.title').first().should('contain', 'About');
  });

  it('should Overview link navigates to its correspondent section', () => {
    cy.get('.l-section-nav').find('a[href="#overview"]').should('contain', 'overview').click();
    cy.url().should('include', '#overview');
    cy.get('#overview').find('h2').should('contain', 'Overview').and('be.visible');
  });

  it('should Using Resilience Atlas link navigates to its correspondent section', () => {
    cy.get('.l-section-nav')
      .find('a[href="#using_the_atlas"]')
      .should('contain', 'using RESILIENCE ATLAS')
      .click();
    cy.url().should('include', '#using_the_atlas');
    cy.get('#using_the_atlas')
      .find('h2')
      .should('contain', 'Using RESILIENCE ATLAS')
      .and('be.visible');
  });

  it('should Team link navigates to its correspondent section', () => {
    cy.get('.l-section-nav').find('a[href="#team"]').should('contain', 'team').click();
    cy.url().should('include', '#team');
    cy.get('#team').find('h2').should('contain', 'team').and('be.visible');
  });

  it('should Sponsors link navigates to its correspondent section', () => {
    cy.get('.l-section-nav').find('a[href="#sponsors"]').should('contain', 'sponsors').click();
    cy.url().should('include', '#sponsors');
    cy.get('#sponsors').find('h2').should('contain', 'Sponsors').and('be.visible');
  });

  it('should Data policy link navigates to its correspondent section', () => {
    cy.get('.l-section-nav')
      .find('a[href="#data_policy"]')
      .should('contain', 'data policy')
      .click();
    cy.url().should('include', '#data_policy');
    cy.get('#data_policy').find('h2').should('contain', 'Data policy').and('be.visible');
  });

  it('should Glossary link navigates to its correspondent section', () => {
    cy.get('.l-section-nav').find('a[href="#terminology"]').should('contain', 'glossary').click();
    cy.url().should('include', '#terminology');
    cy.get('#terminology').find('h2').should('contain', 'Glossary').and('be.visible');
  });
});
