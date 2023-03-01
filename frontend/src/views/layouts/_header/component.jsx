import React, { useEffect, useCallback } from 'react';
import { NavLink } from 'react-router-dom';
import { sortBy } from '@utilities';

const byPosition = sortBy('position');

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
  }, []);

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
            <NavLink to="/">Resilience Atlas</NavLink>
          </li>
        </ul>

        <ul className="nav-area -resilience">
          <li className="journey-link">
            <NavLink to="/journeys" activeClassName="is-current">
              Journeys
            </NavLink>
          </li>

          <li>
            <NavLink to="/map" activeClassName="is-current">
              Map
            </NavLink>

            <ul>{menuItems.sort(byPosition).map(renderMenuItem)}</ul>
          </li>

          <li>
            <NavLink to="/about" activeClassName="is-current">
              About
            </NavLink>
          </li>

          {loggedIn ? (
            <>
              <li>
                <NavLink to="/me" activeClassName="is-current">
                  Me
                </NavLink>
              </li>

              <li>
                <NavLink to="#" onClick={logout}>
                  Logout
                </NavLink>
              </li>
            </>
          ) : (
            <>
              <li>
                <NavLink to="/login" activeClassName="is-current">
                  Login
                </NavLink>
              </li>

              <li>
                <NavLink to="/register" activeClassName="is-current">
                  Register
                </NavLink>
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
