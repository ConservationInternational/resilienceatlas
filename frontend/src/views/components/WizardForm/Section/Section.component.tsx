import React from 'react';
import cx from 'classnames';

const Section: React.FC<
  React.PropsWithChildren<{
    required?: boolean;
    question: string;
    description?: string;
    error?: boolean;
  }>
> = (props) => {
  const { question, description, required, error = false, children } = props;

  return (
    <section className={cx({ error: error })}>
      <div
        className={cx('m-wizard-form__form-content-title', {
          'm-wizard-form__form-content-title--required': required,
        })}
      >
        {question}
      </div>
      {description && (
        <span className="m-wizard-form__form-content-description">{description}</span>
      )}
      <div className="m-wizard-form__form-content-wrapper">{children}</div>
    </section>
  );
};

export default Section;
