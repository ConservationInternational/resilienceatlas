import React from 'react';
import cx from 'classnames';
import { Form, Field } from 'redux-form';
import { useQuery } from '@tanstack/react-query';
import axios from 'axios';

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
}) => {
  const { data, isLoading } = useQuery(
    ['userProfile', user.auth_token],
    () =>
      axios.get<IEditProfileForm>(`${process.env.NEXT_PUBLIC_API_HOST}/users/me`, {
        headers: {
          Authorization: `Bearer ${user.auth_token}`,
        },
      }),
    {
      enabled: !!user.auth_token,
    },
  );

  const { data: userData } = data || {};

  if (isLoading && !data) return <Loader loading={isLoading} />;
  const submitValue = (<T _str="Update" />) as unknown as string;

  return (
    <Form onSubmit={handleSubmit}>
      <Field
        component={FormInput}
        type="email"
        name="email"
        label={<T _str="Email" />}
        autoFocus
        defaultValue={userData?.email}
      />

      <Field
        component={FormInput}
        name="first_name"
        label={<T _str="First name" />}
        defaultValue={userData?.first_name}
      />

      <Field
        component={FormInput}
        name="last_name"
        label={<T _str="Last name" />}
        defaultValue={userData?.last_name}
      />

      <Field
        component={FormInput}
        name="organization"
        label={<T _str="Organization" />}
        defaultValue={userData?.organization}
      />

      <Field
        component={FormInput}
        name="organization_role"
        label={<T _str="Organization role" />}
        defaultValue={userData?.organization_role}
      />

      <Loader loading={submitting} />

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

export default EditProfileForm;
