import React, { useEffect, useCallback, useState } from 'react';
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

  // Safely destructure site with default values to prevent errors during SSR/hydration
  const { linkback_text = '', linkback_url = '' } = site || {};

  useEffect(() => {
    setHasMounted(true);
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

  const renderMenuItem = useCallback(
    ({ id, label, link, children }) => (
      <li key={id} className={cx({ 'is-link': link })}>
        {link ? <a href={link}>{label}</a> : label}

        {!!(children && children.length) && (
          <ul>{children.sort(byPosition).map(renderMenuItem)}</ul>
        )}
      </li>
    ),
    [],
  );

  return (
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

        <ul className="nav-area">
          <LanguageSwitcher translations={translations} />
        </ul>

        <ul className={cx('nav-area', '-resilience', { 'is-open': mobileMenuOpen })}>
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

          <li>
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

          {/* Language switcher in mobile menu */}
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
  );
};

export default Header;
