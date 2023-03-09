describe('Journeys detail page', () => {
  beforeEach(() => {
    cy.intercept('GET', '/api/journeys').as('journeysRequest');
    cy.intercept('GET', '/api/journeys/*').as('journeyDetailRequest');
    cy.visit('/journeys');

    // Navigate to the first journey detail
    cy.wait('@journeysRequest').then(({ response }) => {
      cy.wrap(response.statusCode).should('be.equal', 200);
      cy.get('.m-journey__gridelement').first().find('.btn').click();
    });
  });

  it('should correspond to the API response', () => {
    cy.wait('@journeyDetailRequest').then(({ response }) => {
      cy.wrap(response.statusCode).should('be.equal', 200);

      const { id, steps } = response.body[0];

      steps.forEach((step, stepIndex) => {
        cy.log(`Testing step with index ${stepIndex} and type "${step.type}"`);

        cy.url().should('include', `/journeys/${id}/step/${stepIndex + 1}`);

        switch (step.type) {
          case 'landing':
            cy.get('.l-journey__intro .intro > h1')
              .first()
              .contains(step.title, { matchCase: false });
            cy.get('.l-journey__intro .intro > h3')
              .first()
              .contains(step.theme, { matchCase: false });
            break;

          case 'conclusion':
            cy.get('.l-journey h2').first().contains(step.title, { matchCase: false });

            if (step.subtitle) {
              cy.get('.l-journey h3').first().contains(step.subtitle, { matchCase: false });
            }

            cy.get('.l-journey h3 + div')
              .first()
              .should(($div) => {
                const node = document.createElement('div');
                node.innerHTML = step.content;
                expect($div).to.have.text(node.textContent);
              });
            break;

          case 'chapter':
            cy.get('.l-journey .chapter-intro h1')
              .first()
              .contains(step.title, { matchCase: false });
            cy.get('.l-journey .chapter-intro p')
              .first()
              .contains(step.content, { matchCase: false });
            break;

          case 'embed':
            cy.get('.l-journey .side-bar article > div')
              .first()
              .should(($div) => {
                const node = document.createElement('div');
                node.innerHTML = step.aside;
                expect($div).to.have.text(node.textContent);
              });
            cy.get('.l-journey .btn-check-it')
              .first()
              .invoke('attr', 'href')
              .should((href) => {
                const url = href.replace(new URL(href).origin, '');
                const expectedUrl = step.btnUrl.replace(
                  new URL(step.btnUrl, 'https://www.resilienceatlas.org/').origin,
                  '',
                );
                expect(url).to.eq(expectedUrl);
              });
            break;

          default:
            throw new Error(`No test for the "${step.type}" journey step`);
        }

        if (stepIndex + 1 < steps.length) {
          cy.get('.l-journey').find('.btn-next').click();
        }
      });
    });
  });
});
