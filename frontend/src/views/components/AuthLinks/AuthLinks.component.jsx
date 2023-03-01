import React, { FC } from 'react';
import { RouteComponentProps, NavLink } from 'react-router-dom';

const AuthLinks: FC<RouteComponentProps> = ({ match }) => (
  <>
    {!match.path.match('login') && <NavLink to="/login">Log in</NavLink>}
    {!match.path.match('register') && <NavLink to="/register">Sign up</NavLink>}
  </>
);

export default AuthLinks;
