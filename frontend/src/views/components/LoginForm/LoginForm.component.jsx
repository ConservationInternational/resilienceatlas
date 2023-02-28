import React, { FC } from 'react';
import cx from 'classnames';
import { InjectedFormProps, Form, Field } from 'redux-form';

import FormInput from '@shared/inputs/FormInput';
import Loader from '@shared/Loader';

import { ILoginForm } from '@modules/user';

const LoginForm: FC<InjectedFormProps<ILoginForm>> = ({
  handleSubmit,
  submitting,
  error,
}) => (
  <Form onSubmit={handleSubmit}>
    <Field
      component={FormInput}
      type="email"
      name="email"
      label="Email"
      autoFocus
    />
    <Field
      component={FormInput}
      type="password"
      name="password"
      label="Password"
      autoComplete="off"
    />

    <Loader loading={submitting} />

    {error && error.user_authentication && (
      <div className="m-user-form__error">{error.user_authentication}</div>
    )}

    <div className="actions">
      <input
        className={cx('btn-submit', { 'is-loading': submitting })}
        type="submit"
        name="commit"
        value="Log in"
        disabled={submitting}
      />
    </div>
  </Form>
);

export default LoginForm;
