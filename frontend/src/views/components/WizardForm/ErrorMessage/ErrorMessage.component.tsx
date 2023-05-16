import React from 'react';
import ReactDOM from 'react-dom';
import { T } from '@transifex/react';

interface ErrorMessageProps {
  touched: boolean;
  error: string;
  targetId?: string;
  id?: string;
}

const ErrorMessage = ({ touched, error, targetId, id }: ErrorMessageProps) => {
  const VALIDATION_ERRORS_LABELS = {
    required: <T _str="This is a required question" />,
    custom_empty: <T _str='"Other:" field cannot be empty' />,
  };

  const errorMessage = (() => {
    if (Array.isArray(error)) {
      return error.join(', ');
    }

    return error;
  })();

  const targetErrorElement =
    typeof window !== 'undefined' && !!targetId && document.getElementById(targetId);
  return targetErrorElement ? (
    ReactDOM.createPortal(
      <div>
        {touched && error && (
          <span className="m-wizard-form__form-section-error-message">
            {VALIDATION_ERRORS_LABELS[errorMessage]}
          </span>
        )}
      </div>,
      document.getElementById(targetId),
    )
  ) : (
    <div id={id}>
      {touched && error && (
        <span className="m-wizard-form__form-section-error-message">
          {VALIDATION_ERRORS_LABELS[errorMessage]}
        </span>
      )}
    </div>
  );
};

export default ErrorMessage;
