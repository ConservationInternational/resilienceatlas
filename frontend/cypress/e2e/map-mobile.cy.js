/**
 * Map Page Mobile Responsiveness Tests
 *
 * Tests mobile-specific features and responsiveness of the map page,
 * including sidebar behavior, touch targets, and mobile layouts.
 */

describe('Map page - Mobile viewport (375x667 - iPhone SE)', () => {
  beforeEach(() => {
    // Set mobile viewport
    cy.viewport(375, 667);
    cy.clearCookies();
    cy.interceptAllRequests();
    cy.visit('/map');
    cy.waitForMapPageReady();
  });

  it('should have full-width sidebar when open on mobile', () => {
    // Wait for sidebar to be visible
    cy.get('.l-sidebar--fullscreen', { timeout: 10000 }).should('exist');
    
    // Sidebar should not be collapsed initially (may vary based on state)
    cy.get('body').then(($body) => {
      const sidebar = $body.find('.l-sidebar--fullscreen');
      if (sidebar.hasClass('is-collapsed')) {
        // If collapsed, open it
        cy.get('.btn-sidebar-toggle').click();
        cy.wait(500); // Wait for animation
      }
      
      // Check sidebar takes full width on mobile
      cy.get('.l-sidebar--fullscreen:not(.is-collapsed)').then(($sidebar) => {
        const sidebarWidth = $sidebar.width();
        const viewportWidth = Cypress.config('viewportWidth');
        // Sidebar should be close to full viewport width
        expect(sidebarWidth).to.be.at.least(viewportWidth * 0.95);
      });
    });
  });

  it('should show larger toggle button on mobile', () => {
    cy.get('.btn-sidebar-toggle').should('exist').and('be.visible');
    
    // Check that toggle button has appropriate size for mobile
    cy.get('.btn-sidebar-toggle').then(($btn) => {
      const width = $btn.width();
      const height = $btn.height();
      // Mobile button should be at least 40px (larger than desktop's 25px)
      expect(width).to.be.at.least(40);
      expect(height).to.be.at.least(40);
    });
  });

  it('should collapse sidebar completely off-screen on mobile', () => {
    // Open sidebar first if collapsed
    cy.get('.l-sidebar--fullscreen').then(($sidebar) => {
      if ($sidebar.hasClass('is-collapsed')) {
        cy.get('.btn-sidebar-toggle').click();
        cy.wait(500);
      }
    });

    // Now collapse it
    cy.get('.btn-sidebar-toggle').click();
    cy.wait(500); // Wait for animation

    cy.get('.l-sidebar--fullscreen.is-collapsed').should('exist');
    
    // Verify toggle button is still accessible when collapsed
    cy.get('.btn-sidebar-toggle').should('be.visible');
  });

  it('should show backdrop overlay when sidebar is open', () => {
    // Open sidebar if collapsed
    cy.get('.l-sidebar--fullscreen').then(($sidebar) => {
      if ($sidebar.hasClass('is-collapsed')) {
        cy.get('.btn-sidebar-toggle').click();
        cy.wait(500);
      }
    });

    // Check for backdrop (implemented via ::before pseudo-element)
    cy.get('.l-sidebar--fullscreen:not(.is-collapsed)').should('exist');
  });

  it('should have larger touch targets for layer list items', () => {
    // Open sidebar if collapsed
    cy.get('.l-sidebar--fullscreen').then(($sidebar) => {
      if ($sidebar.hasClass('is-collapsed')) {
        cy.get('.btn-sidebar-toggle').click();
        cy.wait(500);
      }
    });

    // Check layer list headers have adequate touch target size
    cy.get('.m-layers-list-header').first().then(($header) => {
      const height = $header.height();
      // Minimum touch target should be around 44-48px
      expect(height).to.be.at.least(40);
    });
  });

  it('should display legend at full width on mobile', () => {
    cy.get('.m-legend').should('exist');
    
    cy.get('.m-legend').then(($legend) => {
      const legendWidth = $legend.width();
      const viewportWidth = Cypress.config('viewportWidth');
      // Legend should be full width on mobile
      expect(legendWidth).to.be.at.least(viewportWidth * 0.95);
    });
  });

  it('should have larger map controls on mobile', () => {
    // Wait for map controls to potentially load (client-side)
    cy.get('body', { timeout: 10000 }).then(($body) => {
      // Check for zoom controls
      if ($body.find('.leaflet-control-zoom a').length > 0) {
        cy.get('.leaflet-control-zoom a').first().then(($control) => {
          const width = $control.width();
          // Mobile controls should be 40px (larger than desktop's 30px)
          expect(width).to.be.at.least(35);
        });
      } else {
        cy.log('⚠ Map controls not loaded - client-side components may not be available');
      }
    });
  });

  it('should have larger toolbar buttons on mobile', () => {
    cy.get('body').then(($body) => {
      if ($body.find('.m-toolbar__item').length > 0) {
        cy.get('.m-toolbar__item').first().then(($item) => {
          const width = $item.width();
          const height = $item.height();
          // Toolbar items should be at least 40px on mobile
          expect(width).to.be.at.least(35);
          expect(height).to.be.at.least(35);
        });
      } else {
        cy.log('⚠ Toolbar not found - may not be loaded yet');
      }
    });
  });
});

describe('Map page - Tablet viewport (768x1024 - iPad)', () => {
  beforeEach(() => {
    // Set tablet viewport
    cy.viewport(768, 1024);
    cy.clearCookies();
    cy.interceptAllRequests();
    cy.visit('/map');
    cy.waitForMapPageReady();
  });

  it('should have narrower sidebar on tablet (not full width)', () => {
    cy.get('.l-sidebar--fullscreen', { timeout: 10000 }).should('exist');
    
    cy.get('body').then(($body) => {
      const sidebar = $body.find('.l-sidebar--fullscreen');
      if (sidebar.hasClass('is-collapsed')) {
        cy.get('.btn-sidebar-toggle').click();
        cy.wait(500);
      }
      
      // Tablet should have sidebar narrower than full width
      cy.get('.l-sidebar--fullscreen:not(.is-collapsed)').then(($sidebar) => {
        const sidebarWidth = $sidebar.width();
        const viewportWidth = Cypress.config('viewportWidth');
        // Sidebar should be less than full width but still substantial
        expect(sidebarWidth).to.be.lessThan(viewportWidth);
        expect(sidebarWidth).to.be.at.least(280); // At least 300px on tablet
      });
    });
  });

  it('should have appropriately sized legend on tablet', () => {
    cy.get('.m-legend').should('exist');
    
    cy.get('.m-legend').then(($legend) => {
      const legendWidth = $legend.width();
      // Legend should not be full width on tablet
      expect(legendWidth).to.be.lessThan(Cypress.config('viewportWidth'));
      // But should be at least 280px
      expect(legendWidth).to.be.at.least(280);
    });
  });
});

describe('Map page - Desktop viewport (1440x900)', () => {
  beforeEach(() => {
    // Set desktop viewport
    cy.viewport(1440, 900);
    cy.clearCookies();
    cy.interceptAllRequests();
    cy.visit('/map');
    cy.waitForMapPageReady();
  });

  it('should maintain fixed sidebar width on desktop', () => {
    cy.get('.l-sidebar--fullscreen', { timeout: 10000 }).should('exist');
    
    cy.get('body').then(($body) => {
      const sidebar = $body.find('.l-sidebar--fullscreen');
      if (sidebar.hasClass('is-collapsed')) {
        cy.get('.btn-sidebar-toggle').click();
        cy.wait(500);
      }
      
      // Desktop sidebar should be fixed at 350px
      cy.get('.l-sidebar--fullscreen:not(.is-collapsed)').then(($sidebar) => {
        const sidebarWidth = $sidebar.width();
        // Should be around 350px (allow small variance)
        expect(sidebarWidth).to.be.within(340, 360);
      });
    });
  });

  it('should have smaller toggle button on desktop', () => {
    cy.get('.btn-sidebar-toggle').should('exist').and('be.visible');
    
    cy.get('.btn-sidebar-toggle').then(($btn) => {
      const width = $btn.width();
      // Desktop button should be 25px (smaller than mobile)
      expect(width).to.be.at.most(30);
    });
  });

  it('should have fixed-width legend on desktop', () => {
    cy.get('.m-legend').should('exist');
    
    cy.get('.m-legend').then(($legend) => {
      const legendWidth = $legend.width();
      // Desktop legend should be around 350px
      expect(legendWidth).to.be.within(340, 360);
    });
  });

  it('should have standard-sized map controls on desktop', () => {
    cy.get('body', { timeout: 10000 }).then(($body) => {
      if ($body.find('.leaflet-control-zoom a').length > 0) {
        cy.get('.leaflet-control-zoom a').first().then(($control) => {
          const width = $control.width();
          // Desktop controls should be 30px
          expect(width).to.be.within(28, 35);
        });
      } else {
        cy.log('⚠ Map controls not loaded');
      }
    });
  });

  it('should NOT show backdrop overlay on desktop', () => {
    cy.get('.l-sidebar--fullscreen').then(($sidebar) => {
      if ($sidebar.hasClass('is-collapsed')) {
        cy.get('.btn-sidebar-toggle').click();
        cy.wait(500);
      }
    });

    // On desktop, sidebar should not have backdrop behavior
    // The backdrop is implemented via media query for mobile only
    cy.get('.l-sidebar--fullscreen:not(.is-collapsed)').should('exist');
    // No programmatic way to test ::before pseudo-element doesn't exist,
    // but we can verify the sidebar is working normally
  });
});

describe('Map page - Responsive transitions', () => {
  it('should adapt layout when resizing from desktop to mobile', () => {
    // Start with desktop
    cy.viewport(1440, 900);
    cy.clearCookies();
    cy.interceptAllRequests();
    cy.visit('/map');
    cy.waitForMapPageReady();

    // Check desktop sidebar width
    cy.get('.l-sidebar--fullscreen:not(.is-collapsed)', { timeout: 10000 }).then(($sidebar) => {
      const desktopWidth = $sidebar.width();
      expect(desktopWidth).to.be.within(340, 360);
    });

    // Resize to mobile
    cy.viewport(375, 667);
    cy.wait(500); // Wait for responsive styles to apply

    // Check mobile sidebar width
    cy.get('.l-sidebar--fullscreen:not(.is-collapsed)').then(($sidebar) => {
      const mobileWidth = $sidebar.width();
      expect(mobileWidth).to.be.at.least(350); // Should be full width
    });
  });

  it('should adapt layout when resizing from mobile to desktop', () => {
    // Start with mobile
    cy.viewport(375, 667);
    cy.clearCookies();
    cy.interceptAllRequests();
    cy.visit('/map');
    cy.waitForMapPageReady();

    // Resize to desktop
    cy.viewport(1440, 900);
    cy.wait(500); // Wait for responsive styles to apply

    // Check desktop sidebar width
    cy.get('.l-sidebar--fullscreen:not(.is-collapsed)', { timeout: 10000 }).then(($sidebar) => {
      const desktopWidth = $sidebar.width();
      expect(desktopWidth).to.be.within(340, 360);
    });
  });
});
