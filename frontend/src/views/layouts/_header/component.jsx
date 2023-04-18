import React, { useEffect, useCallback } from 'react';
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

  useEffect(() => {
    if (!menuItemsLoaded || menuItemsLoadedLocale !== locale) loadMenuItems(locale);
  }, [loadMenuItems, menuItemsLoaded, menuItemsLoadedLocale, locale]);

  const renderMenuItem = useCallback(
    ({ id, label, link, children }) => (
      <li key={id}>
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
            <Link href="/">
              <a>
                <T _str="Resilience Atlas"></T>
              </a>
            </Link>
          </li>
        </ul>

        <ul className="nav-area -resilience">
          <li className="journey-link">
            <Link href="/journeys">
              <a className={cx(pathname.includes('/journeys') && 'is-current')}>
                <T _str="Journeys" />
              </a>
            </Link>
          </li>

          <li>
            <Link href="/map">
              <a className={cx(pathname.includes('/map') && 'is-current')}>
                <T _str="Map" />
              </a>
            </Link>

            <ul>{menuItems.sort(byPosition).map(renderMenuItem)}</ul>
          </li>

          <li>
            <Link href="/about">
              <a className={cx(pathname.includes('/about') && 'is-current')}>
                <T _str="About" />
              </a>
            </Link>
          </li>

          {loggedIn ? (
            <>
              <li>
                <Link href="/me">
                  <a className={cx(pathname.includes('/me') && 'is-current')}>
                    <T _str="Me" />
                  </a>
                </Link>
              </li>

              <li>
                <button type="button" onClick={logout}>
                  <T _str="Logout" />
                </button>
              </li>
            </>
          ) : (
            <>
              <li>
                <Link href="/login">
                  <a className={cx(pathname.includes('/login') && 'is-current')}>
                    <T _str="Login" />
                  </a>
                </Link>
              </li>

              <li>
                <Link href="/register">
                  <a className={cx(pathname.includes('/register') && 'is-current')}>
                    <T _str="Register" />
                  </a>
                </Link>
              </li>
            </>
          )}

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
