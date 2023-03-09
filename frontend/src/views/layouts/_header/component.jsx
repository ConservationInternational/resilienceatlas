import React, { useEffect, useCallback } from 'react';
import Link from 'next/link';
import { sortBy } from 'utilities';

const byPosition = sortBy('position');

/**
 * TO-DO: Migrate active class for Link component
 */

const Header = ({
  loadMenuItems,
  logout,
  loggedIn,
  site: { linkback_text, linkback_url },
  menuItems,
  menuItemsLoaded,
}) => {
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
            <Link href="/journeys" activeClassName="is-current">
              <a>Journeys</a>
            </Link>
          </li>

          <li>
            <Link href="/map" activeClassName="is-current">
              <a>Map</a>
            </Link>

            <ul>{menuItems.sort(byPosition).map(renderMenuItem)}</ul>
          </li>

          <li>
            <Link href="/about" activeClassName="is-current">
              <a>About</a>
            </Link>
          </li>

          {loggedIn ? (
            <>
              <li>
                <Link href="/me" activeClassName="is-current">
                  <a>Me</a>
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
                <Link href="/login" activeClassName="is-current">
                  <a>Login</a>
                </Link>
              </li>

              <li>
                <Link href="/register" activeClassName="is-current">
                  <a>Register</a>
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
