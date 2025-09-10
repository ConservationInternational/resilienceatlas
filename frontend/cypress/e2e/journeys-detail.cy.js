describe('Journeys detail page', () => {
  beforeEach(() => {
    cy.interceptAllRequests();

    cy.visit('/journeys');

    // Navigate to the first journey detail
    cy.wait('@journeyListRequest').then(({ response }) => {
      cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);
      cy.get('.m-journey__gridelement').first().find('.btn').click();
    });
  });

  it('should correspond to the API response', () => {
    cy.wait('@journeyDetailRequest').then(({ response }) => {
      cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);
      const {
        included: steps,
        data: { id },
      } = response.body;

      steps.forEach((step, stepIndex) => {
        const {
          step_type: type,
          title,
          subtitle,
          description,
          map_url: btnUrl,
          content,
        } = step.attributes;

        cy.log(`Testing step with index ${stepIndex} and type "${type}"`);

        cy.url().should('include', `/journeys/${id}/step/${stepIndex + 1}`);

        const isRelativeUrl = (url) => url && url.startsWith('/');
        const embeddedUrl = isRelativeUrl(btnUrl)
          ? `/en${btnUrl}`
          : btnUrl && btnUrl.replace(/(\/[^\/]+\/)/, '$1en/');
        const expectedUrl = type === 'embed' ? embeddedUrl : null;

        switch (type) {
          case 'landing':
            cy.get('.l-journey__intro .intro > h1').first().contains(title, { matchCase: false });
            cy.get('.l-journey__intro .intro > h3')
              .first()
              .contains(description, { matchCase: false });
            break;

          case 'conclusion':
            cy.get('.l-journey h2').first().contains(title, { matchCase: false });

            if (subtitle) {
              cy.get('.l-journey h3').first().contains(subtitle, { matchCase: false });
            }

            cy.get('.l-journey h3 + div')
              .first()
              .should(($div) => {
                const node = document.createElement('div');
                node.innerHTML = content;
                expect($div).to.have.text(node.textContent);
              });
            break;

          case 'chapter':
            cy.get('.l-journey .chapter-intro h1').first().contains(title, { matchCase: false });
            cy.get('.l-journey .chapter-intro p')
              .first()
              .contains(description, { matchCase: false });
            break;

          case 'embed':
            cy.get('.l-journey .side-bar article .content > div')
              .first()
              .should(($div) => {
                const node = document.createElement('div');
                node.innerHTML = content;
                expect($div).to.have.text(node.textContent);
              });
            cy.get('.l-journey .side-bar article h2')
              .first()
              .should(($div) => {
                const node = document.createElement('div');
                node.innerHTML = title;
                expect($div).to.have.text(node.textContent);
              });
            cy.get('.l-journey .side-bar article h3')
              .first()
              .should(($div) => {
                const node = document.createElement('div');
                node.innerHTML = subtitle;
                expect($div).to.have.text(node.textContent);
              });
            cy.get('.l-journey .btn-check-it')
              .first()
              .invoke('attr', 'href')
              .should('be.equal', expectedUrl);
            break;

          default:
            throw new Error(`No test for the "${type}" journey step`);
        }

        if (stepIndex + 1 < steps.length) {
          cy.get('.l-journey').find('.btn-next').click();
        }
      });
    });
  });
});
