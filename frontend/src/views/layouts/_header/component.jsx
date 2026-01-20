import React, { useEffect, useCallback, useState } from 'react';
import { createPortal } from 'react-dom';
import { useRouter } from 'next/router';
import Link from 'next/link';
import cx from 'classnames';
import { sortBy } from 'utilities';
import LanguageSwitcher from 'views/components/LanguageSwitcher';
import { T } from '@transifex/react';

const byPosition = sortBy('position');

const Header = ({
  loadMenuItems,
  logout,
  loggedIn,
  site,
  menuItems,
  menuItemsLoaded,
  menuItemsLoadedLocale,
  translations,
}) => {
  const router = useRouter();
  const { pathname, locale } = router;
  const [hasMounted, setHasMounted] = useState(false);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [expandedMenuItems, setExpandedMenuItems] = useState({});
  const [portalContainer, setPortalContainer] = useState(null);

  // Safely destructure site with default values to prevent errors during SSR/hydration
  const { linkback_text = '', linkback_url = '' } = site || {};

  useEffect(() => {
    setHasMounted(true);
    // Set up portal container for mobile menu
    setPortalContainer(document.body);
  }, []);

  useEffect(() => {
    if (!menuItemsLoaded || menuItemsLoadedLocale !== locale) loadMenuItems(locale);
  }, [loadMenuItems, menuItemsLoaded, menuItemsLoadedLocale, locale]);

  // Close mobile menu when route changes
  useEffect(() => {
    setMobileMenuOpen(false);
  }, [pathname]);

  // Toggle mobile menu
  const toggleMobileMenu = useCallback(() => {
    setMobileMenuOpen((prev) => !prev);
  }, []);

  // Toggle nested menu item expansion on mobile
  const toggleMenuItemExpansion = useCallback((e, hasChildren) => {
    // Only handle on mobile (check window width)
    if (typeof window !== 'undefined' && window.innerWidth <= 767 && hasChildren) {
      e.preventDefault();
      const itemId = e.currentTarget.getAttribute('data-menu-id');
      setExpandedMenuItems((prev) => ({
        ...prev,
        [itemId]: !prev[itemId],
      }));
    }
  }, []);

  const renderMenuItem = useCallback(
    ({ id, label, link, children }) => {
      const hasChildren = !!(children && children.length);
      const isExpanded = expandedMenuItems[id];

      return (
        <li
          key={id}
          className={cx({
            'is-link': link,
            'is-expanded': isExpanded,
          })}
          data-menu-id={id}
        >
          {link ? (
            <a href={link} onClick={(e) => toggleMenuItemExpansion(e, hasChildren)}>
              {label}
              {hasChildren && (
                <span className="mobile-expand-indicator">{isExpanded ? ' ▲' : ' ▼'}</span>
              )}
            </a>
          ) : (
            <span
              onClick={(e) => toggleMenuItemExpansion(e, hasChildren)}
              style={{ cursor: hasChildren ? 'pointer' : 'default' }}
            >
              {label}
              {hasChildren && (
                <span className="mobile-expand-indicator">{isExpanded ? ' ▲' : ' ▼'}</span>
              )}
            </span>
          )}

          {hasChildren && <ul>{children.sort(byPosition).map(renderMenuItem)}</ul>}
        </li>
      );
    },
    [expandedMenuItems, toggleMenuItemExpansion],
  );

  return (
    <>
      <header className="l-header--fullscreen">
        <nav className="l-header-nav">
          <ul className="brand-area">
            <li>
              <Link
                href="/"
                style={{
                  display: 'block',
                  cursor: 'pointer',
                  textDecoration: 'none',
                  color: '#333333',
                }}
              >
                <T _str="Resilience Atlas"></T>
              </Link>
            </li>
          </ul>

          {/* Mobile menu toggle button */}
          <button
            className={cx('mobile-menu-toggle', { 'is-open': mobileMenuOpen })}
            onClick={toggleMobileMenu}
            aria-label={
              mobileMenuOpen
                ? translations?.['Close menu'] || 'Close menu'
                : translations?.['Open menu'] || 'Open menu'
            }
            type="button"
          >
            <span />
          </button>

          {/* Desktop navigation - hidden on mobile */}
          <ul className="nav-area -resilience desktop-only">
            <li className="journey-link">
              <Link
                href="/journeys"
                className={pathname.includes('/journeys') ? 'nav-current-forced' : ''}
                style={{
                  display: 'block',
                  padding: '10px',
                  cursor: 'pointer',
                  textDecoration: 'none',
                  fontSize: '14px',
                  textTransform: 'uppercase',
                  borderRadius: '3px',
                  transition: '0.2s ease-in',
                  ...(!pathname.includes('/journeys') && { color: 'var(--theme-color, #333333)' }),
                }}
              >
                <T _str="Journeys" />
              </Link>
            </li>

            <li
              className={cx({ 'is-expanded': expandedMenuItems['map-menu'] })}
              data-menu-id="map-menu"
            >
              <Link
                href="/map"
                className={pathname.includes('/map') ? 'nav-current-forced' : ''}
                style={{
                  display: 'block',
                  padding: '10px',
                  cursor: 'pointer',
                  textDecoration: 'none',
                  fontSize: '14px',
                  textTransform: 'uppercase',
                  borderRadius: '3px',
                  transition: '0.2s ease-in',
                  ...(!pathname.includes('/map') && { color: 'var(--theme-color, #333333)' }),
                }}
              >
                <T _str="Map" />
              </Link>

              <ul>{(menuItems || []).sort(byPosition).map(renderMenuItem)}</ul>
            </li>

            <li>
              <Link
                href="/about"
                className={pathname.includes('/about') ? 'nav-current-forced' : ''}
                style={{
                  display: 'block',
                  padding: '10px',
                  cursor: 'pointer',
                  textDecoration: 'none',
                  fontSize: '14px',
                  textTransform: 'uppercase',
                  borderRadius: '3px',
                  transition: '0.2s ease-in',
                  ...(!pathname.includes('/about') && { color: 'var(--theme-color, #333333)' }),
                }}
              >
                <T _str="About" />
              </Link>
            </li>

            {hasMounted && loggedIn ? (
              <>
                <li>
                  <Link
                    href="/me"
                    className={pathname.includes('/me') ? 'nav-current-forced' : ''}
                    style={{
                      display: 'block',
                      padding: '10px',
                      cursor: 'pointer',
                      textDecoration: 'none',
                      fontSize: '14px',
                      textTransform: 'uppercase',
                      borderRadius: '3px',
                      transition: '0.2s ease-in',
                      ...(!pathname.includes('/me') && { color: 'var(--theme-color, #333333)' }),
                    }}
                  >
                    <T _str="Me" />
                  </Link>
                </li>

                <li>
                  <button type="button" onClick={logout}>
                    <T _str="Logout" />
                  </button>
                </li>
              </>
            ) : hasMounted ? (
              <>
                <li>
                  <Link
                    href="/login"
                    className={pathname.includes('/login') ? 'nav-current-forced' : ''}
                    style={{
                      display: 'block',
                      padding: '10px',
                      cursor: 'pointer',
                      textDecoration: 'none',
                      fontSize: '14px',
                      textTransform: 'uppercase',
                      borderRadius: '3px',
                      transition: '0.2s ease-in',
                      ...(!pathname.includes('/login') && { color: 'var(--theme-color, #333333)' }),
                    }}
                  >
                    <T _str="Login" />
                  </Link>
                </li>

                <li>
                  <Link
                    href="/register"
                    className={pathname.includes('/register') ? 'nav-current-forced' : ''}
                    style={{
                      display: 'block',
                      padding: '10px',
                      cursor: 'pointer',
                      textDecoration: 'none',
                      fontSize: '14px',
                      textTransform: 'uppercase',
                      borderRadius: '3px',
                      transition: '0.2s ease-in',
                      ...(!pathname.includes('/register') && {
                        color: 'var(--theme-color, #333333)',
                      }),
                    }}
                  >
                    <T _str="Register" />
                  </Link>
                </li>
              </>
            ) : null}

            <LanguageSwitcher translations={translations} />
          </ul>

          <ul className="nav-area -vital-sign">
            <li>
              <a
                href={linkback_url || 'http://vitalsigns.org/'}
                target="_blank"
                rel="noopener noreferrer"
                className="theme-color link-back"
              >
                {linkback_text || <T _str="Go back to vital signs" />}
              </a>
            </li>
          </ul>
        </nav>
        <ul className="m-journey__paginationlist" />
      </header>

      {/* Mobile menu rendered via portal to escape header's stacking context */}
      {portalContainer &&
        mobileMenuOpen &&
        createPortal(
          <div className="mobile-menu-overlay" onClick={toggleMobileMenu}>
            <ul className="mobile-menu-panel" onClick={(e) => e.stopPropagation()}>
              <li className="journey-link">
                <Link
                  href="/journeys"
                  className={pathname.includes('/journeys') ? 'nav-current-forced' : ''}
                  onClick={toggleMobileMenu}
                >
                  <T _str="Journeys" />
                </Link>
              </li>

              <li
                className={cx({ 'is-expanded': expandedMenuItems['map-menu'] })}
                data-menu-id="map-menu"
              >
                <Link
                  href="/map"
                  onClick={(e) => {
                    if (menuItems?.length > 0) {
                      e.preventDefault();
                      setExpandedMenuItems((prev) => ({
                        ...prev,
                        ['map-menu']: !prev['map-menu'],
                      }));
                    } else {
                      toggleMobileMenu();
                    }
                  }}
                >
                  <T _str="Map" />
                  {menuItems?.length > 0 && (
                    <span className="mobile-expand-indicator">
                      {expandedMenuItems['map-menu'] ? ' ▲' : ' ▼'}
                    </span>
                  )}
                </Link>

                {expandedMenuItems['map-menu'] && (
                  <ul className="mobile-submenu">
                    {/* Add main Resilience Atlas map link at the top */}
                    <li key="main-map">
                      <Link href="/map" onClick={toggleMobileMenu}>
                        <T _str="Resilience Atlas" />
                      </Link>
                    </li>
                    {(menuItems || []).sort(byPosition).map((item) => {
                      const hasChildren = !!(item.children && item.children.length);
                      const isItemExpanded = expandedMenuItems[`mobile-${item.id}`];

                      return (
                        <li key={item.id} className={cx({ 'is-expanded': isItemExpanded })}>
                          {item.link ? (
                            <a
                              href={item.link}
                              onClick={(e) => {
                                if (hasChildren) {
                                  e.preventDefault();
                                  setExpandedMenuItems((prev) => ({
                                    ...prev,
                                    [`mobile-${item.id}`]: !prev[`mobile-${item.id}`],
                                  }));
                                } else {
                                  toggleMobileMenu();
                                }
                              }}
                            >
                              {item.label}
                              {hasChildren && (
                                <span className="mobile-expand-indicator">
                                  {isItemExpanded ? ' ▲' : ' ▼'}
                                </span>
                              )}
                            </a>
                          ) : (
                            <span
                              onClick={() => {
                                if (hasChildren) {
                                  setExpandedMenuItems((prev) => ({
                                    ...prev,
                                    [`mobile-${item.id}`]: !prev[`mobile-${item.id}`],
                                  }));
                                }
                              }}
                              style={{ cursor: hasChildren ? 'pointer' : 'default' }}
                            >
                              {item.label}
                              {hasChildren && (
                                <span className="mobile-expand-indicator">
                                  {isItemExpanded ? ' ▲' : ' ▼'}
                                </span>
                              )}
                            </span>
                          )}
                          {hasChildren && isItemExpanded && (
                            <ul className="mobile-submenu-nested">
                              {item.children.sort(byPosition).map((child) => (
                                <li key={child.id}>
                                  {child.link ? (
                                    <a href={child.link} onClick={toggleMobileMenu}>
                                      {child.label}
                                    </a>
                                  ) : (
                                    <span>{child.label}</span>
                                  )}
                                </li>
                              ))}
                            </ul>
                          )}
                        </li>
                      );
                    })}
                  </ul>
                )}
              </li>

              <li>
                <Link href="/about" onClick={toggleMobileMenu}>
                  <T _str="About" />
                </Link>
              </li>

              {hasMounted && loggedIn ? (
                <>
                  <li>
                    <Link href="/me" onClick={toggleMobileMenu}>
                      <T _str="Me" />
                    </Link>
                  </li>
                  <li>
                    <button
                      type="button"
                      onClick={() => {
                        logout();
                        toggleMobileMenu();
                      }}
                    >
                      <T _str="Logout" />
                    </button>
                  </li>
                </>
              ) : hasMounted ? (
                <>
                  <li>
                    <Link href="/login" onClick={toggleMobileMenu}>
                      <T _str="Login" />
                    </Link>
                  </li>
                  <li>
                    <Link href="/register" onClick={toggleMobileMenu}>
                      <T _str="Register" />
                    </Link>
                  </li>
                </>
              ) : null}

              <LanguageSwitcher translations={translations} />
            </ul>
          </div>,
          portalContainer,
        )}
    </>
  );
};

export default Header;
