import React, { FC } from 'react';
import cx from 'classnames';
import { InjectedFormProps, Form, Field } from 'redux-form';

import FormInput from '@shared/inputs/FormInput';
import Loader from '@shared/Loader';
import { IEditProfileForm } from '@modules/user';

const EditProfileForm: FC<InjectedFormProps<IEditProfileForm>> = ({
  handleSubmit,
  submitting,
}) => (
  <Form onSubmit={handleSubmit}>
    <Field
      component={FormInput}
      type="email"
      name="email"
      label="Email"
      autoFocus
    />

    <Field component={FormInput} name="first_name" label="First name" />

    <Field component={FormInput} name="last_name" label="Last name" />

    <Field component={FormInput} name="organization" label="Organization" />

    <Field
      component={FormInput}
      name="organization_role"
      label="Organization role"
    />

    <Loader loading={submitting} />

    <div className="actions">
      <input
        className={cx('btn-submit', { 'is-loading': submitting })}
        type="submit"
        name="commit"
        value="Update"
        disabled={submitting}
      />
    </div>
  </Form>
);

export default EditProfileForm;
