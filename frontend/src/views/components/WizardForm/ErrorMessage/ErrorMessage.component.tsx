import React from 'react';

const ErrorMessage = ({ touched, error }) => {
  const errorMessage = (() => {
    if (Array.isArray(error)) {
      return error.join(', ');
    }

    return error;
  })();

  return (
    <>
      {touched && error && (
        <span className="m-wizard-form__form-section-error-message">{errorMessage}</span>
      )}
    </>
  );
};

export default ErrorMessage;
