import type { FC } from 'react';
import React from 'react';
import cx from 'classnames';
import type { InjectedFormProps } from 'redux-form';
import { Form, Field } from 'redux-form';
import { T } from '@transifex/react';

import FormInput from 'views/shared/inputs/FormInput';
import Loader from 'views/shared/Loader';

import type { ILoginForm } from 'state/modules/user';

const LoginForm: FC<InjectedFormProps<ILoginForm>> = ({ handleSubmit, submitting, error }) => {
  const submitValue = (<T _str="Log in" />) as unknown as string;
  return (
    <Form onSubmit={handleSubmit}>
      <Field component={FormInput} type="email" name="email" label="Email" autoFocus />
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
          value={submitValue}
          disabled={submitting}
        />
      </div>
    </Form>
  );
};

export default LoginForm;
