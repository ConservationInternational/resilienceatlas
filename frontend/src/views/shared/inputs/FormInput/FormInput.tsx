import type { ReactNode, InputHTMLAttributes } from 'react';
import React, { useMemo, forwardRef } from 'react';
import cx from 'classnames';
import type { FieldError } from 'react-hook-form';

interface FormInputProps extends InputHTMLAttributes<HTMLInputElement> {
  label: ReactNode;
  name: string;
  error?: FieldError;
  touched?: boolean;
}

const FormInput = forwardRef<HTMLInputElement, FormInputProps>(
  ({ label, name, error, touched, defaultValue, ...rest }, ref) => {
    const errorMessage = useMemo(() => {
      if (!error) return null;
      if (Array.isArray(error)) {
        return error.map((e) => e.message).join(', ');
      }
      return error.message;
    }, [error]);

    const hasError = Boolean(error);

    return (
      <div className={cx('field', { 'has-error': hasError })}>
        <label htmlFor={name}>{label}</label>
        <br />
        <input {...rest} ref={ref} name={name} id={name} defaultValue={defaultValue} />
        {Boolean((touched || hasError) && errorMessage) && (
          <div className="error-message">{errorMessage}</div>
        )}
      </div>
    );
  },
);

FormInput.displayName = 'FormInput';

export default FormInput;
