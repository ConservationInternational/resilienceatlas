import React from 'react';
import { NavLink } from 'react-router-dom';
import { Row } from 'react-foundation';
import LoginForm from '@components/LoginForm';

const Login = () => (
  <div className="l-content">
    <Row>
      <div className="m-user-form">
        <h2>Log in</h2>

        <LoginForm />

        <NavLink to="/register">Sign up</NavLink>
      </div>
    </Row>
  </div>
);

export default Login;
