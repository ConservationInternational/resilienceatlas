import React from 'react';
import cx from 'classnames';
import { Form, Field } from 'redux-form';

import FormInput from 'views/shared/inputs/FormInput';
import Loader from 'views/shared/Loader';
import { T } from '@transifex/react';

import type { FC } from 'react';
import type { InjectedFormProps } from 'redux-form';
import type { IEditProfileForm } from 'state/modules/user';

const EditProfileForm: FC<InjectedFormProps<IEditProfileForm>> = ({
  user,
  handleSubmit,
  submitting,
  error,
}) => {
  return (
    <>
      {error && <p className="general-error-message">{error}</p>}
      <Form onSubmit={handleSubmit}>
        <Field
          component={FormInput}
          type="email"
          name="email"
          label={<T _str="Email" />}
          autoFocus
          defaultValue={user.data?.email ?? ''}
        />

        <Field
          component={FormInput}
          name="first_name"
          label={<T _str="First name" />}
          defaultValue={user.data?.first_name ?? ''}
        />

        <Field
          component={FormInput}
          name="last_name"
          label={<T _str="Last name" />}
          defaultValue={user.data?.last_name ?? ''}
        />

        <Field
          component={FormInput}
          name="organization"
          label={<T _str="Organization" />}
          defaultValue={user.data?.organization ?? ''}
        />

        <Field
          component={FormInput}
          name="organization_role"
          label={<T _str="Organization role" />}
          defaultValue={user.data?.organization_role ?? ''}
        />

        <Loader loading={submitting} />

        <div className="actions">
          <button
            className={cx('btn-submit', { 'is-loading': submitting })}
            type="submit"
            name="commit"
            disabled={submitting}
          >
            <T _str="Update" />
          </button>
        </div>
      </Form>
    </>
  );
};

export default EditProfileForm;
