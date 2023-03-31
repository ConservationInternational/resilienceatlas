import type { FC, ReactNode } from 'react';
import React, { useMemo } from 'react';
import cx from 'classnames';
import type { WrappedFieldProps } from 'redux-form';

interface P {
  label: ReactNode;
}

const FormInput: FC<P & WrappedFieldProps> = ({
  input,
  meta: { touched, error },
  label,
  defaultValue,
  ...rest
}) => {
  const errorMessage = useMemo(() => {
    if (Array.isArray(error)) {
      return error.join(', ');
    }

    return error;
  }, [error]);
  const value = !!input.value && input.value !== '' ? input.value : defaultValue;

  return (
    <div className={cx('field', { 'has-error': error })}>
      <label htmlFor={input.name}>{label}</label>
      <br />
      <input {...input} {...rest} value={value} />
      {Boolean(touched && error) && <div className="error-message">{errorMessage}</div>}
    </div>
  );
};

export default FormInput;
