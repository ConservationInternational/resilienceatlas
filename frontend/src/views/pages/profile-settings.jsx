import React, { FC } from 'react';
import { connect } from 'react-redux';
import { NavLink, RouteComponentProps } from 'react-router-dom';
import { Row } from 'react-foundation';

import ProfileSettingsForm from '@components/ProfileSettingsForm';

const ProfileSettings: FC<RouteComponentProps> = ({ history, user }) => (
  <div className="l-content">
    <Row>
      <div className="m-user-form">
        <h2>
          Edit {user.first_name} {user.last_name}
        </h2>
        <ProfileSettingsForm />
        <h3>Cancel my account</h3>

        <p>Unhappy?</p>

        <input type="submit" value="Cancel my account" />

        <NavLink to="#" onClick={history.goBack}>
          Back
        </NavLink>
      </div>
    </Row>
  </div>
);

export default connect(state => ({ user: state.user }))(ProfileSettings);
