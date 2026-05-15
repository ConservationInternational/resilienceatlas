import type { FC } from 'react';
import React, { useState } from 'react';
import cx from 'classnames';
import { useForm } from 'react-hook-form';
import type { Resolver } from 'react-hook-form';
import { yupResolver } from '@hookform/resolvers/yup';
import { T } from '@transifex/react';
import { useSelector, useDispatch } from 'react-redux';
import type { ThunkDispatch } from 'redux-thunk';
import type { UnknownAction } from 'redux';

import FormInput from 'views/shared/inputs/FormInput';
import Loader from 'views/shared/Loader';

import { EditProfileSchema, editProfile, loadUserData } from 'state/modules/user';
import type { IEditProfileForm } from 'state/modules/user';
import type { RootState } from 'state/types';

type AppDispatch = ThunkDispatch<unknown, unknown, UnknownAction>;

const EditProfileForm: FC = () => {
  const dispatch = useDispatch<AppDispatch>();
  const user = useSelector((state: RootState) => state.user);
  const [showSuccess, setShowSuccess] = useState(false);

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
    setError,
  } = useForm<IEditProfileForm>({
    resolver: yupResolver(EditProfileSchema) as Resolver<IEditProfileForm>,
    mode: 'onBlur',
    defaultValues: {
      email: user.data?.email ?? '',
      first_name: user.data?.first_name ?? '',
      last_name: user.data?.last_name ?? '',
      organization: user.data?.organization ?? '',
      organization_role: user.data?.organization_role ?? '',
    },
  });

  const onSubmit = async (data: IEditProfileForm) => {
    try {
      setShowSuccess(false);
      await editProfile(data, user.auth_token);
      dispatch(loadUserData());
      setShowSuccess(true);
    } catch (err: unknown) {
      const error = err as { errors?: Record<string, string>; _error?: string };
      if (error.errors) {
        Object.entries(error.errors).forEach(([field, message]) => {
          setError(field as keyof IEditProfileForm, { type: 'server', message });
        });
      } else if (error._error) {
        setError('root.serverError', {
          type: 'server',
          message: error._error,
        });
      }
    }
  };

  const serverError = errors.root?.serverError?.message;

  return (
    <>
      {showSuccess && (
        <p className="success-message">
          <T _str="Your profile has been updated successfully." />
        </p>
      )}
      {serverError && <p className="general-error-message">{serverError}</p>}
      <form onSubmit={handleSubmit(onSubmit)}>
        <FormInput
          {...register('email')}
          type="email"
          label={<T _str="Email" />}
          autoFocus
          error={errors.email}
        />

        <FormInput
          {...register('first_name')}
          label={<T _str="First name" />}
          error={errors.first_name}
        />

        <FormInput
          {...register('last_name')}
          label={<T _str="Last name" />}
          error={errors.last_name}
        />

        <FormInput
          {...register('organization')}
          label={<T _str="Organization" />}
          error={errors.organization}
        />

        <FormInput
          {...register('organization_role')}
          label={<T _str="Organization role" />}
          error={errors.organization_role}
        />

        <Loader loading={isSubmitting} />

        <div className="actions">
          <button
            className={cx('btn-submit', { 'is-loading': isSubmitting })}
            type="submit"
            name="commit"
            disabled={isSubmitting}
          >
            <T _str="Update" />
          </button>
        </div>
      </form>
    </>
  );
};

export default EditProfileForm;
