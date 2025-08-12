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
  site: { linkback_text, linkback_url },
  menuItems,
  menuItemsLoaded,
  menuItemsLoadedLocale,
  translations,
}) => {
  const { pathname, locale } = useRouter();
  const [hasMounted, setHasMounted] = useState(false);

  useEffect(() => {
    setHasMounted(true);
  }, []);

  useEffect(() => {
    if (!menuItemsLoaded || menuItemsLoadedLocale !== locale) loadMenuItems(locale);
  }, [loadMenuItems, menuItemsLoaded, menuItemsLoadedLocale, locale]);

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
                color: 'var(--theme-color, #333)',
              }}
            >
              <T _str="Resilience Atlas"></T>
            </Link>
          </li>
        </ul>
        <ul className="nav-area">
          <LanguageSwitcher translations={translations} />
        </ul>
        <ul className="nav-area -resilience">
          <li className="journey-link">
            <Link
              href="/journeys"
              className={cx(pathname.includes('/journeys') && 'is-current')}
              style={{
                display: 'block',
                padding: '10px',
                cursor: 'pointer',
                textDecoration: 'none',
                color: 'var(--theme-color, #333)',
                fontSize: '14px',
                textTransform: 'uppercase',
              }}
            >
              <T _str="Journeys" />
            </Link>
          </li>

          <li>
            <Link
              href="/map"
              className={cx(pathname.includes('/map') && 'is-current')}
              style={{
                display: 'block',
                padding: '10px',
                cursor: 'pointer',
                textDecoration: 'none',
                color: 'var(--theme-color, #333)',
                fontSize: '14px',
                textTransform: 'uppercase',
              }}
            >
              <T _str="Map" />
            </Link>

            <ul>{menuItems.sort(byPosition).map(renderMenuItem)}</ul>
          </li>

          <li>
            <Link
              href="/about"
              className={cx(pathname.includes('/about') && 'is-current')}
              style={{
                display: 'block',
                padding: '10px',
                cursor: 'pointer',
                textDecoration: 'none',
                color: 'var(--theme-color, #333)',
                fontSize: '14px',
                textTransform: 'uppercase',
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
                  className={cx(pathname.includes('/me') && 'is-current')}
                  style={{
                    display: 'block',
                    padding: '10px',
                    cursor: 'pointer',
                    textDecoration: 'none',
                    color: 'var(--theme-color, #333)',
                    fontSize: '14px',
                    textTransform: 'uppercase',
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
                  className={cx(pathname.includes('/login') && 'is-current')}
                  style={{
                    display: 'block',
                    padding: '10px',
                    cursor: 'pointer',
                    textDecoration: 'none',
                    color: 'var(--theme-color, #333)',
                    fontSize: '14px',
                    textTransform: 'uppercase',
                  }}
                >
                  <T _str="Login" />
                </Link>
              </li>

              <li>
                <Link
                  href="/register"
                  className={cx(pathname.includes('/register') && 'is-current')}
                  style={{
                    display: 'block',
                    padding: '10px',
                    cursor: 'pointer',
                    textDecoration: 'none',
                    color: 'var(--theme-color, #333)',
                    fontSize: '14px',
                    textTransform: 'uppercase',
                  }}
                >
                  <T _str="Register" />
                </Link>
              </li>
            </>
          ) : null}
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
