import React, { useEffect, useCallback } from 'react';
import { useRouter } from 'next/router';
import Link from 'next/link';
import cx from 'classnames';
import { sortBy } from 'utilities';

const byPosition = sortBy('position');

const Header = ({
  loadMenuItems,
  logout,
  loggedIn,
  site: { linkback_text, linkback_url },
  menuItems,
  menuItemsLoaded,
}) => {
  const { pathname } = useRouter();

  useEffect(() => {
    if (!menuItemsLoaded) loadMenuItems();
  }, [loadMenuItems, menuItemsLoaded]);

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
              <a>Resilience Atlas</a>
            </Link>
          </li>
        </ul>

        <ul className="nav-area -resilience">
          <li className="journey-link">
            <Link href="/journeys">
              <a className={cx(pathname.includes('/journeys') && 'is-current')}>Journeys</a>
            </Link>
          </li>

          <li>
            <Link href="/map">
              <a className={cx(pathname.includes('/map') && 'is-current')}>Map</a>
            </Link>

            <ul>{menuItems.sort(byPosition).map(renderMenuItem)}</ul>
          </li>

          <li>
            <Link href="/about">
              <a className={cx(pathname.includes('/about') && 'is-current')}>About</a>
            </Link>
          </li>

          {loggedIn ? (
            <>
              <li>
                <Link href="/me">
                  <a className={cx(pathname.includes('/me') && 'is-current')}>Me</a>
                </Link>
              </li>

              <li>
                <button type="button" onClick={logout}>
                  Logout
                </button>
              </li>
            </>
          ) : (
            <>
              <li>
                <Link href="/login">
                  <a className={cx(pathname.includes('/login') && 'is-current')}>Login</a>
                </Link>
              </li>

              <li>
                <Link href="/register">
                  <a className={cx(pathname.includes('/register') && 'is-current')}>Register</a>
                </Link>
              </li>
            </>
          )}
        </ul>

        <ul className="nav-area -vital-sign">
          <li>
            <a
              href={linkback_url || 'http://vitalsigns.org/'}
              target="_blank"
              rel="noopener noreferrer"
              className="theme-color link-back"
            >
              {linkback_text || 'Go back to vital signs'}
            </a>
          </li>
        </ul>
      </nav>
      <ul className="m-journey__paginationlist" />
    </header>
  );
};

export default Header;
