import type { FC } from 'react';
import React from 'react';
import cx from 'classnames';
import type { InjectedFormProps } from 'redux-form';
import { Form, Field } from 'redux-form';

import FormInput from 'views/shared/inputs/FormInput';
import Loader from 'views/shared/Loader';
import type { ISignupForm } from 'state/modules/user';

const LoginForm: FC<InjectedFormProps<ISignupForm>> = ({ handleSubmit, submitting }) => (
  <Form onSubmit={handleSubmit}>
    <Field component={FormInput} type="email" name="email" label="Email" autoFocus />

    <Field
      component={FormInput}
      type="password"
      name="password"
      label={
        <span>
          Password<em>(8 characters minimum)</em>
        </span>
      }
      autoComplete="off"
    />

    <Field
      component={FormInput}
      type="password"
      name="password_confirmation"
      label="Password confirmation"
      autoComplete="off"
    />

    <Field component={FormInput} name="first_name" label="First name" />

    <Field component={FormInput} name="last_name" label="Last name" />

    <Field component={FormInput} name="organization" label="Organization" />

    <Field component={FormInput} name="organization_role" label="Organization role" />

    <Loader loading={submitting} />

    <div className="actions">
      <input
        className={cx('btn-submit', { 'is-loading': submitting })}
        type="submit"
        name="commit"
        value="Sign up"
        disabled={submitting}
      />
    </div>
  </Form>
);

export default LoginForm;
