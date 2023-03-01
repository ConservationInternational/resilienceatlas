import React from 'react';
import { connect } from 'react-redux';
import { Row } from 'react-foundation';
import { NavLink } from 'react-router-dom';

import EditProfileForm from '@components/EditProfileForm';

const Me = ({ user }) => (
  <div className="l-content">
    <Row>
      <div className="m-user-form">
        <h2>
          Edit {user.first_name} {user.last_name}
        </h2>

        <EditProfileForm />

        <NavLink to="/profile-settings">Manage account</NavLink>
      </div>
    </Row>
  </div>
);

export default connect(state => ({ user: state.user }))(Me);
