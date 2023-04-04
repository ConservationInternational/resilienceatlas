import type { FC } from 'react';
import React from 'react';
import cx from 'classnames';
import type { InjectedFormProps } from 'redux-form';
import { Form, Field } from 'redux-form';
import { T } from '@transifex/react';

import FormInput from 'views/shared/inputs/FormInput';
import Loader from 'views/shared/Loader';
import type { ISignupForm } from 'state/modules/user';

const LoginForm: FC<InjectedFormProps<ISignupForm>> = ({ handleSubmit, submitting }) => (
  <Form onSubmit={handleSubmit}>
    <Field component={FormInput} type="email" name="email" label={<T _str="Email" />} autoFocus />

    <Field
      component={FormInput}
      type="password"
      name="password"
      label={
        <span>
          <T
            _str="Password {minimum_chars}"
            _comment="Password {(8 characters minimum)}"
            minimum_chars={
              <em>
                <T _str="(8 characters minimum)" _comment="Password {(8 characters minimum)}" />
              </em>
            }
          />
        </span>
      }
      autoComplete="off"
    />

    <Field
      component={FormInput}
      type="password"
      name="password_confirmation"
      label={<T _str="Password confirmation" />}
      autoComplete="off"
    />

    <Field component={FormInput} name="first_name" label={<T _str="First name" />} />

    <Field component={FormInput} name="last_name" label={<T _str="Last name" />} />

    <Field component={FormInput} name="organization" label={<T _str="Organization" />} />

    <Field component={FormInput} name="organization_role" label={<T _str="Organization role" />} />

    <Loader loading={submitting} />

    <div className="actions">
      <input
        className={cx('btn-submit', { 'is-loading': submitting })}
        type="submit"
        name="commit"
        value={(<T _str="Sign up" />) as unknown as string}
        disabled={submitting}
      />
    </div>
  </Form>
);

export default LoginForm;
