describe('About page', () => {
  beforeEach(() => {
    cy.interceptAllRequests();
    cy.visit('/about');
    cy.wait('@siteRequest').then(({ response }) => {
      cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);
    });
  });

  context('intro', () => {
    it('should display the correct content', () => {
      cy.wait('@aboutRequest').then(({ response }) => {
        cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);
        const { attributes } = response.body.data;
        const { title, image, image_credits, image_credits_url } = attributes;
        cy.get('.l-hero').within(() => {
          cy.get('h1').should('contain', title);
        });

        if (image?.original) {
          cy.get('.l-hero').should(
            'have.attr',
            'style',
            `background-image: url("${image?.original}");`,
          );

          if (image_credits && image_credits_url) {
            cy.get('.credits')
              .first()
              .within(() => {
                cy.get('a')
                  .should('contain', image_credits)
                  .should('have.attr', 'href', image_credits_url);
              });
          }
        }
      });
    });
  });

  context('nav', () => {
    it('should display the correct sections', () => {
      cy.wait('@aboutRequest').then(({ response }) => {
        cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);
        const allSections = response.body.included;
        const sectionsToBeDisplayed = allSections.filter((s) => s.attributes.show_at_navigation);

        cy.get('.m-section-nav').within(() => {
          cy.get('li').should('have.length', sectionsToBeDisplayed.length);
          cy.get('li').each(($el, index) => {
            cy.wrap($el).within(() => {
              cy.get('a')
                .should('contain', sectionsToBeDisplayed[index].attributes.title)
                .should('have.attr', 'href', `#${sectionsToBeDisplayed[index].attributes.slug}`);
            });
          });
        });
      });
    });
  });

  context('sections', () => {
    it('should display the correct sections with title', () => {
      cy.wait('@aboutRequest').then(({ response }) => {
        cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);
        const allSections = response.body.included;
        const staticPageSections = allSections.filter((s) => s.type === 'static_page_sections');
        cy.get('.m-static-page').within(() => {
          cy.get('article').should('have.length', staticPageSections.length);
          cy.get('article').each(($el, index) => {
            cy.wrap($el).within(() => {
              const titleTag = staticPageSections[index].attributes.title_size === 2 ? 'h2' : 'h3';
              cy.get(titleTag).should('contain', staticPageSections[index].attributes.title);
            });
          });
        });
      });
    });

    it('paragraph sections should show image and text in correct order', () => {
      cy.wait('@aboutRequest').then(({ response }) => {
        cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);
        const allSections = response.body.included;
        const staticPageSectionsWithParagraph = allSections.filter(
          (s) => s.type === 'static_page_sections' && s.relationships.section_paragraph.data,
        );
        cy.get('.m-static-page').within(() => {
          staticPageSectionsWithParagraph.map((section) => {
            cy.get(`article#${section.attributes.slug}`).within(() => {
              const paragraphSection = allSections.find(
                (s) =>
                  s.type === 'static_page_section_paragraphs' &&
                  s.id === section.relationships.section_paragraph.data.id,
              );
              const { text, image, image_position, image_credits, image_credits_url } =
                paragraphSection.attributes;
              if (text) {
                // We don't test content because of parsing
                cy.get('.text-column').should('exist');
              }
              if (image?.original) {
                cy.get('.image-column').should('exist');
                cy.get('img').should('have.attr', 'src', image?.original);

                if (image_credits) {
                  cy.get('.credits').within(() => {
                    cy.get('a')
                      .should('contain', image_credits)
                      .should('have.attr', 'href', image_credits_url);
                  });
                }
                if (image_position === 'right') {
                  cy.get('.text-column').next().should('have.class', 'image-column');
                }
                if (image_position === 'left') {
                  cy.get('.image-column').next().should('have.class', 'text-column');
                }
              }
            });
          });
        });
      });
    });

    it('item sections should show items', () => {
      cy.wait('@aboutRequest').then(({ response }) => {
        cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);
        const allSections = response.body.included;
        const staticPageSectionsWithItems = allSections.filter(
          (s) => s.type === 'static_page_sections' && s.relationships.section_items.data?.length,
        );
        cy.get('.m-static-page').within(() => {
          staticPageSectionsWithItems.map((section) => {
            cy.get(`article#${section.attributes.slug}`).within(() => {
              // Find paragraph in allSections
              const itemIds = section.relationships.section_items.data.map((i) => i.id);
              const items = allSections.filter(
                (s) => s.type === 'static_page_section_items' && itemIds.includes(s.id),
              );
              cy.get('section').should('have.length', items.length);
              cy.get('section').each(($el, index) => {
                const { attributes } = items[index];
                cy.wrap($el).within(() => {
                  cy.get('h3').should('contain', attributes.title);
                  if (attributes.description) {
                    // We don't test content because of parsing
                    cy.get('[data-test="item-description"]').should('exist');
                  }
                  if (attributes.image?.original) {
                    cy.get('img').should('have.attr', 'src', attributes.image?.original);
                  }
                });
              });
            });
          });
        });
      });
    });

    it.only('reference sections should show references', () => {
      cy.wait('@aboutRequest').then(({ response }) => {
        cy.wrap(response.statusCode).should('be.oneOf', [200, 304]);
        const allSections = response.body.included;
        const staticPageSectionsWithReferences = allSections.filter(
          (s) =>
            s.type === 'static_page_sections' && s.relationships.section_references.data?.length,
        );
        cy.get('.m-static-page').within(() => {
          staticPageSectionsWithReferences.map((section) => {
            cy.get(`article#${section.attributes.slug}`).within(() => {
              // Find paragraph in allSections
              const referenceIds = section.relationships.section_references.data.map((i) => i.id);
              const references = allSections.filter(
                (s) => s.type === 'static_page_section_references' && referenceIds.includes(s.id),
              );
              cy.get('p').should('have.length', references.length);
              references.map((reference) => {
                const { attributes } = reference;
                cy.get(`p#${attributes.slug}`).should('not.be.empty');
              });
            });
          });
        });
      });
    });
  });
});
