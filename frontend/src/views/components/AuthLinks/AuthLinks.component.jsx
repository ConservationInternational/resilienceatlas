import type { FC } from 'react';
import React from 'react';
import type { RouteComponentProps } from 'react-router-dom';
import { NavLink } from 'react-router-dom';

const AuthLinks: FC<RouteComponentProps> = ({ match }) => (
  <>
    {!match.path.match('login') && <NavLink to="/login">Log in</NavLink>}
    {!match.path.match('register') && <NavLink to="/register">Sign up</NavLink>}
  </>
);

export default AuthLinks;
