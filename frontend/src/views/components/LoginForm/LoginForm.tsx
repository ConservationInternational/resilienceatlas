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

import { LoginSchema, signin, login } from 'state/modules/user';
import type { ILoginForm } from 'state/modules/user';

type AppDispatch = ThunkDispatch<unknown, unknown, UnknownAction>;

interface LoginFormError {
  user_authentication?: string;
}

const LoginForm: FC = () => {
  const router = useRouter();
  const dispatch = useDispatch<AppDispatch>();
  const { query: { from = '/' } = {} } = router;

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
    setError,
  } = useForm<ILoginForm>({
    resolver: yupResolver(LoginSchema) as Resolver<ILoginForm>,
    mode: 'onBlur',
  });

  const onSubmit = async (data: ILoginForm) => {
    try {
      const authToken = await signin(data);
      dispatch(login(authToken));

      if (from && router.isReady) {
        router.push(from as string);
      }
    } catch (err: unknown) {
      const error = err as { _error?: LoginFormError };
      if (error._error?.user_authentication) {
        setError('root.serverError', {
          type: 'server',
          message: error._error.user_authentication,
        });
      }
    }
  };

  const serverError = errors.root?.serverError?.message;

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <FormInput {...register('email')} type="email" label="Email" autoFocus error={errors.email} />
      <FormInput
        {...register('password')}
        type="password"
        label="Password"
        autoComplete="off"
        error={errors.password}
      />

      <Loader loading={isSubmitting} />

      {serverError && <div className="m-user-form__error">{serverError}</div>}

      <div className="actions">
        <button
          className={cx('btn-submit', { 'is-loading': isSubmitting })}
          type="submit"
          name="commit"
          disabled={isSubmitting}
        >
          <T _str="Log in" />
        </button>
      </div>
    </form>
  );
};

export default LoginForm;
