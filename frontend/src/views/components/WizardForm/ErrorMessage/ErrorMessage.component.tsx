import React from 'react';
import ReactDOM from 'react-dom';

const ErrorMessage = ({ touched, error, targetId, id }) => {
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
          <span className="m-wizard-form__form-section-error-message">{errorMessage}</span>
        )}
      </div>,
      document.getElementById(targetId),
    )
  ) : (
    <div id={id}>
      {touched && error && (
        <span className="m-wizard-form__form-section-error-message">{errorMessage}</span>
      )}
    </div>
  );
};

export default ErrorMessage;
