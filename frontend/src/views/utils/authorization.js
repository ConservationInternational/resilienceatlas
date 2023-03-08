import React from 'react';
import { connect } from 'react-redux';
import { Redirect } from 'react-router-dom';

import { getUserLoggedIn } from 'state/modules/user';

export const SHARED = 'SHARED';
export const LOGGED = 'LOGGED';
export const UNLOGGED = 'UNLOGGED';

const authorization = (auth) => (Wrapped) => {
  const authorized = ({ logged, ...rest }) => {
    if (auth !== SHARED && auth !== logged) {
      return <Redirect to="/" />;
    }

    return <Wrapped {...rest} />;
  };

  return connect((state) => ({
    logged: getUserLoggedIn(state) ? LOGGED : UNLOGGED,
    site: state.site,
  }))(authorized);
};

export default authorization;
