import type { FC } from 'react';
import React, { useState } from 'react';
import cx from 'classnames';
import { useForm } from 'react-hook-form';
import type { Resolver } from 'react-hook-form';
import { yupResolver } from '@hookform/resolvers/yup';
import { T, useT } from '@transifex/react';
import { useSelector, useDispatch } from 'react-redux';
import type { ThunkDispatch } from 'redux-thunk';
import type { UnknownAction } from 'redux';

import FormInput from 'views/shared/inputs/FormInput';
import Loader from 'views/shared/Loader';

import { ProfileSettingsSchema, editProfile, loadUserData } from 'state/modules/user';
import type { IProfileSettingsForm } from 'state/modules/user';
import type { RootState } from 'state/types';

type AppDispatch = ThunkDispatch<unknown, unknown, UnknownAction>;

const ProfileSettingsForm: FC = () => {
  const t = useT();
  const dispatch = useDispatch<AppDispatch>();
  const user = useSelector((state: RootState) => state.user);
  const [showSuccess, setShowSuccess] = useState(false);

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
    setError,
  } = useForm<IProfileSettingsForm>({
    resolver: yupResolver(ProfileSettingsSchema) as Resolver<IProfileSettingsForm>,
    mode: 'onBlur',
    defaultValues: {
      email: user.data?.email ?? '',
    },
  });

  const onSubmit = async (data: IProfileSettingsForm) => {
    try {
      setShowSuccess(false);
      // Only include password fields if password was provided
      const submitData = {
        email: data.email,
        ...(data.password
          ? { password: data.password, password_confirmation: data.password_confirmation }
          : {}),
      };
      await editProfile(submitData as Parameters<typeof editProfile>[0], user.auth_token);
      dispatch(loadUserData());
      setShowSuccess(true);
    } catch (err: unknown) {
      const error = err as { errors?: Record<string, string>; _error?: string };
      if (error.errors) {
        Object.entries(error.errors).forEach(([field, message]) => {
          setError(field as keyof IProfileSettingsForm, { type: 'server', message });
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
          <T _str="Your settings have been updated successfully." />
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

        {!!user.unconfirmed && (
          <div>
            <T _str="Currently waiting confirmation for: {email}" email={user.data?.email} />
          </div>
        )}

        <FormInput
          {...register('password')}
          type="password"
          label={
            <span>
              <T
                _str="Password {leave_it_blank}"
                _comment="Password <em>(leave blank if you don't want to change it)</em>"
                leave_it_blank={
                  <em>
                    <T
                      _str="(leave blank if you don't want to change it)"
                      _comment="Password <em>(leave blank if you don't want to change it)</em>"
                    />
                  </em>
                }
              />
            </span>
          }
          autoComplete="off"
          error={errors.password}
        />

        <FormInput
          {...register('password_confirmation')}
          type="password"
          label={<T _str="Password confirmation" />}
          autoComplete="off"
          error={errors.password_confirmation}
        />

        <Loader loading={isSubmitting} />

        <div className="actions">
          <input
            className={cx('btn-submit', { 'is-loading': isSubmitting })}
            type="submit"
            name="commit"
            value={t('Update')}
            disabled={isSubmitting}
          />
        </div>
      </form>
    </>
  );
};

export default ProfileSettingsForm;
