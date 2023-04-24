describe('Homepage', () => {
  beforeEach(() => {
    cy.interceptAllRequests();
    cy.visit('/');
    cy.wait('@siteRequest');
  });

  it('should display sections in the correct order', () => {
    cy.wait('@homepageRequest').then(({ response }) => {
      cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);

      const { included } = response.body;
      const journeys = included?.filter(({ type }) => type === 'homepage_journeys') || [];
      const sections = included?.filter(({ type }) => type === 'homepage_sections') || [];

      const orderedSectionTitles = [
        ...journeys.map((journey) => ({
          type: 'journeys',
          section: journey,
        })),
        ...sections.map((section) => ({
          type: 'section',
          section: section,
        })),
      ]
        .sort((a, b) => a.section.position - b.section.position)
        .map(({ section }) => section.attributes.title);

      cy.get('[data-cy="homepage-section"]').should('have.length', orderedSectionTitles.length);

      cy.get('[data-cy="homepage-section"]').each(($el, index) => {
        cy.wrap($el).within(() => {
          cy.get('h2').should('contain', orderedSectionTitles[index]);
        });
      });
    });
  });

  context('intro', () => {
    it('should display the correct content', () => {
      cy.wait('@homepageRequest').then(({ response }) => {
        cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);

        const { attributes } = response.body.data;

        cy.get('.m-home-intro__header').within(() => {
          cy.get('h2').should('contain', attributes.title);
          cy.get('h3').should('contain', attributes.subtitle);
        });

        if (attributes.background_image) {
          cy.get('.m-home-intro').should(
            'have.attr',
            'style',
            `background-image: url("${attributes.background_image?.original}");`,
          );

          if (attributes.credits && attributes.credits_url) {
            cy.get('.m-home-intro__credits').within(() => {
              cy.get('a')
                .should('contain', attributes.credits)
                .should('have.attr', 'href', attributes.credits_url);
            });
          }
        }
      });
    });

    it('should display the correct background image and credits', () => {
      cy.wait('@homepageRequest').then(({ response }) => {
        cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);

        const { attributes } = response.body.data;

        if (attributes.background_image) {
          cy.get('.m-home-intro').should(
            'have.attr',
            'style',
            `background-image: url("${attributes.background_image?.original}");`,
          );

          if (attributes.credits && attributes.credits_url) {
            cy.get('.m-home-intro__credits').within(() => {
              cy.get('a')
                .should('contain', attributes.credits)
                .should('have.attr', 'href', attributes.credits_url);
            });
          }
        }
      });
    });
  });

  context('journeys', () => {
    it('should display the section if returned by the API', () => {
      cy.wait('@homepageRequest').then(({ response }) => {
        cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);

        const { included: sections } = response.body;
        const journeySections = sections?.filter(({ type }) => type === 'homepage_journeys');

        cy.get('.m-home-journeys').should('have.length', journeySections?.length || 0);
      });
    });

    it('should display the correct content', () => {
      cy.wait('@homepageRequest').then(({ response }) => {
        cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);

        const { included: sections } = response.body;
        const journeysSection = sections?.find(({ type }) => type === 'homepage_journeys');
        const { attributes } = journeysSection;

        if (!journeysSection) return cy.skip();

        cy.get('.m-home-journeys').within(() => {
          cy.get('h2').should('contain', attributes.title);
          cy.get('.slick-list').should('exist');
          cy.get('.m-home-journeys__bottom .btn')
            .should('contain', 'More journeys')
            .should('have.attr', 'href', '/journeys');
        });
      });
    });

    it('should display the correct journeys content', () => {
      cy.wait('@homepageRequest').then(({ response }) => {
        cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);

        const { included } = response.body;
        const journeysSection = included?.filter(({ type }) => type === 'homepage_journeys')[0];

        if (!journeysSection) return cy.skip();

        cy.wait('@journeyListRequest').then(({ response }) => {
          cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);

          const journeys = response.body.data;

          if (!journeys) return cy.skip();

          cy.get('.m-slider').within(() => {
            cy.get('.slick-slide')
              .not('.slick-cloned')
              .each(($el, index) => {
                const { id, attributes } = journeys[index];

                cy.wrap($el).within(() => {
                  cy.get('.journey-link-container')
                    .should('have.attr', 'href', `/journeys/${id}`)
                    .should(
                      'have.attr',
                      'style',
                      `background-image: url("${attributes.background_image.original}");`,
                    );

                  cy.get('h2').should('contain', attributes.subtitle);
                  cy.get('h3').should('contain', attributes.title);

                  cy.get('.credits a')
                    .should('contain', attributes.credits)
                    .should('have.attr', 'href', attributes.credits_url);
                });
              });
          });
        });
      });
    });
  });

  context('sections', () => {
    it('should display sections if returned by the API', () => {
      cy.wait('@homepageRequest').then(({ response }) => {
        cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);

        const { included } = response.body;
        const sections = included?.filter(({ type }) => type === 'homepage_sections');

        cy.get('.m-home-section').should('have.length', sections.length || 0);
      });
    });

    it('should display the correct sections content', () => {
      cy.wait('@homepageRequest').then(({ response }) => {
        cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);

        const { included } = response.body;
        const sections = included?.filter(({ type }) => type === 'homepage_sections');

        if (!sections) return cy.skip();

        cy.get('.m-home-section').each(($el, index) => {
          const { attributes } = sections[index];

          cy.wrap($el).within(() => {
            cy.get('h2').should('contain', attributes.title);

            if (attributes.subtitle) {
              cy.get('p').should('contain', attributes.subtitle);
            }

            if (attributes.button_text && attributes.button_url) {
              cy.get('a.btn')
                .should('contain', attributes.button_text)
                .should('have.attr', 'href', attributes.button_url);
            }
          });
        });
      });
    });

    it('should position images and background color correctly', () => {
      cy.wait('@homepageRequest').then(({ response }) => {
        cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);

        const { included } = response.body;
        const sections = included?.filter(({ type }) => type === 'homepage_sections');

        if (!sections) return cy.skip();

        cy.get('.m-home-section').each(($el, index) => {
          const { attributes } = sections[index];

          // Background color
          if (attributes.background_color) {
            cy.hexToRgb(attributes.background_color).then((rgb) => {
              cy.wrap($el)
                .then(($el) => {
                  return window.getComputedStyle($el[0]);
                })
                .invoke('getPropertyValue', 'background-color')
                .should('equal', rgb);
            });
          }

          // COVER IMAGES
          if (attributes.image_position === 'cover') {
            if (attributes.image) {
              cy.wrap($el)
                .then(($el) => {
                  return window.getComputedStyle($el[0]);
                })
                .invoke('getPropertyValue', 'background-image')
                .should('equal', `url("${attributes.image.original}")`);

              cy.wrap($el)
                .then(($el) => {
                  return window.getComputedStyle($el[0]);
                })
                .invoke('getPropertyValue', 'background-size')
                .should('equal', 'cover');
            }

            if (attributes.image_credits && attributes.image_credits_url) {
              cy.wrap($el).within(() => {
                cy.get('.m-home-section__credits')
                  .should('have.class', 'm-home-section__credits--right')
                  .within(() => {
                    cy.get('a')
                      .should('contain', attributes.image_credits)
                      .should('have.attr', 'href', attributes.image_credits_url);
                  });
              });
            }
          }

          // RIGHT ALIGNED
          if (attributes.image_position === 'right') {
            if (attributes.image) {
              cy.wrap($el)
                .get('.m-home-section__figure')
                .should('have.class', 'm-home-section__figure--right');

              // TODO: Fix this test. This is related to cypress caching the image probably
              // cy.wrap($el)
              //   .get('.m-home-section__figure')
              //   .should(
              //     'have.attr',
              //     'style',
              //     `background-image: url("${attributes.image.original}");`,
              //   );
            }

            if (attributes.image_credits && attributes.image_credits_url) {
              cy.wrap($el).within(() => {
                cy.get('.m-home-section__credits')
                  .should('have.class', 'm-home-section__credits--right')
                  .within(() => {
                    cy.get('a')
                      .should('contain', attributes.image_credits)
                      .should('have.attr', 'href', attributes.image_credits_url);
                  });
              });
            }
          }

          // LEFT ALIGNED
          if (attributes.image_position === 'left') {
            if (attributes.image) {
              cy.wrap($el)
                .get('.m-home-section__figure')
                .should('have.class', 'm-home-section__figure--left');

              // TODO: Fix this test. This is related to cypress caching the image probably
              // cy.wrap($el)
              //   .get('.m-home-section__figure')
              //   .should(
              //     'have.attr',
              //     'style',
              //     `background-image: url("${attributes.image.original}");`,
              //   );
            }

            if (attributes.image_credits && attributes.image_credits_url) {
              cy.wrap($el).within(() => {
                cy.get('.m-home-section__credits')
                  .should('have.class', 'm-home-section__credits--left')
                  .within(() => {
                    cy.get('a')
                      .should('contain', attributes.image_credits)
                      .should('have.attr', 'href', attributes.image_credits_url);
                  });
              });
            }
          }
        });
      });
    });
  });
});
