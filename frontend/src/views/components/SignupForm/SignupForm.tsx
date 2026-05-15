import type { FC } from 'react';
import React from 'react';
import cx from 'classnames';
import { useForm } from 'react-hook-form';
import type { Resolver } from 'react-hook-form';
import { yupResolver } from '@hookform/resolvers/yup';
import { T } from '@transifex/react';
import { useRouter } from 'next/router';
import { useDispatch } from 'react-redux';
import type { ThunkDispatch } from 'redux-thunk';
import type { UnknownAction } from 'redux';

import FormInput from 'views/shared/inputs/FormInput';
import Loader from 'views/shared/Loader';

import { SignupSchema, signup, signin, login } from 'state/modules/user';
import type { ISignupForm } from 'state/modules/user';

type AppDispatch = ThunkDispatch<unknown, unknown, UnknownAction>;

const SignupForm: FC = () => {
  const router = useRouter();
  const dispatch = useDispatch<AppDispatch>();
  const { query: { from = '/' } = {} } = router;

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
    setError,
  } = useForm<ISignupForm>({
    resolver: yupResolver(SignupSchema) as Resolver<ISignupForm>,
    mode: 'onBlur',
  });

  const onSubmit = async (data: ISignupForm) => {
    try {
      await signup(data);
      const authToken = await signin({ email: data.email, password: data.password });
      dispatch(login(authToken));

      // Redirect to the page user came from, or home page
      if (from && router.isReady) {
        router.push(from as string);
      }
    } catch (err: unknown) {
      const error = err as { errors?: Record<string, string> };
      if (error.errors) {
        Object.entries(error.errors).forEach(([field, message]) => {
          setError(field as keyof ISignupForm, { type: 'server', message });
        });
      } else {
        setError('root.serverError', {
          type: 'server',
          message: 'An error occurred during registration',
        });
      }
    }
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <FormInput
        {...register('email')}
        type="email"
        label={<T _str="Email" />}
        autoFocus
        error={errors.email}
      />

      <FormInput
        {...register('password')}
        type="password"
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
        error={errors.password}
      />

      <FormInput
        {...register('password_confirmation')}
        type="password"
        label={<T _str="Password confirmation" />}
        autoComplete="off"
        error={errors.password_confirmation}
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
          <T _str="Sign up" />
        </button>
      </div>
    </form>
  );
};

export default SignupForm;
