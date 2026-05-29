import React, { useEffect, useCallback, useState } from 'react';
import { createPortal } from 'react-dom';
import { useRouter } from 'next/router';
import Link from 'next/link';
import cx from 'classnames';
import { sortBy } from 'utilities';
import LanguageSwitcher from 'views/components/LanguageSwitcher';
import { T } from '@transifex/react';

const byPosition = sortBy('position');

/**
 * Returns a readable color for the linkback text on mobile.
 * The mobile menu panel has a white background, so light colors (e.g. white)
 * would be invisible. If the provided color is too light, falls back to the
 * site theme color or a dark default.
 */
const getMobileLinkbackColor = (color, themeColor) => {
  if (!color) return undefined;

  const normalized = color.trim().toLowerCase().replace(/\s/g, '');

  let r, g, b;

  if (normalized.startsWith('#')) {
    const hex = normalized.slice(1);
    const fullHex =
      hex.length === 3
        ? hex
            .split('')
            .map((c) => c + c)
            .join('')
        : hex;
    if (fullHex.length !== 6) return themeColor || '#333333';
    r = parseInt(fullHex.substring(0, 2), 16);
    g = parseInt(fullHex.substring(2, 4), 16);
    b = parseInt(fullHex.substring(4, 6), 16);
  } else if (normalized.startsWith('rgb(')) {
    const parts = normalized.slice(4, -1).split(',');
    if (parts.length < 3) return themeColor || '#333333';
    r = parseInt(parts[0], 10);
    g = parseInt(parts[1], 10);
    b = parseInt(parts[2], 10);
  } else {
    // Named colors or other formats – be conservative and keep the original
    return color;
  }

  // Calculate perceived luminance (range 0–1)
  const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;

  // Colors with luminance > 0.7 are too light for a white background
  if (luminance > 0.7) {
    return themeColor || '#333333';
  }

  return color;
};

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
  const {
    linkback_text = '',
    linkback_url = '',
    linkback_text_color,
    subdomain = '',
    color = '',
    name = '',
    logo_urls = [],
  } = site || {};

  // Check if we're on a sub-scope (not the main Resilience Atlas site)
  const isSubScope = !!subdomain;

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
            {logo_urls.length > 0 ? (
              logo_urls.map((url, index) => (
                <li key={index}>
                  <Link href="/" aria-label={index === 0 ? name || 'Resilience Atlas' : undefined}>
                    <img
                      src={url}
                      alt={index === 0 ? name || 'Resilience Atlas' : ''}
                      className="site-logo"
                    />
                  </Link>
                </li>
              ))
            ) : (
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
            )}
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
                className={pathname.includes('/journeys') ? 'is-current' : ''}
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
                className={pathname.includes('/map') ? 'is-current' : ''}
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
                className={pathname.includes('/about') ? 'is-current' : ''}
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
                    className={pathname.includes('/me') ? 'is-current' : ''}
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
                    className={pathname.includes('/login') ? 'is-current' : ''}
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
                    className={pathname.includes('/register') ? 'is-current' : ''}
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

          {linkback_url && (
            <ul className="nav-area -linkback">
              <li>
                <a
                  href={linkback_url}
                  target="_blank"
                  rel="noopener noreferrer"
                  className={cx('link-back', { 'theme-color': !linkback_text_color })}
                  {...(linkback_text_color && { style: { color: linkback_text_color } })}
                >
                  {linkback_text || <T _str="Go back" />}
                </a>
              </li>
            </ul>
          )}
        </nav>
        <ul className="m-journey__paginationlist" />
      </header>

      {/* Mobile menu rendered via portal to escape header's stacking context */}
      {portalContainer &&
        mobileMenuOpen &&
        createPortal(
          <div className="mobile-menu-overlay" onClick={toggleMobileMenu}>
            <ul className="mobile-menu-panel" onClick={(e) => e.stopPropagation()}>
              {/* For sub-scopes, only show linkback button like on desktop */}
              {isSubScope && linkback_url ? (
                <li className="mobile-linkback">
                  <a
                    href={linkback_url}
                    target="_blank"
                    rel="noopener noreferrer"
                    className={cx('link-back', { 'theme-color': !linkback_text_color })}
                    onClick={toggleMobileMenu}
                    {...(linkback_text_color && {
                      style: { color: getMobileLinkbackColor(linkback_text_color, color) },
                    })}
                  >
                    {linkback_text || <T _str="Go back" />}
                  </a>
                </li>
              ) : (
                <>
                  <li className="journey-link">
                    <Link
                      href="/journeys"
                      className={pathname.includes('/journeys') ? 'is-current' : ''}
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
                </>
              )}
            </ul>
          </div>,
          portalContainer,
        )}
    </>
  );
};

export default Header;
