import React from 'react';
import cx from 'classnames';
import { T } from '@transifex/react';

import Boolean from 'views/components/WizardForm/FieldTypes/Boolean';
import Single from 'views/components/WizardForm/FieldTypes/Single';
import Multiple from 'views/components/WizardForm/FieldTypes/Multiple';
import FreeAnswer from 'views/components/WizardForm/FieldTypes/FreeAnswer';
import Rating from 'views/components/WizardForm/FieldTypes/Rating';

import ErrorMessage from 'views/components/WizardForm/ErrorMessage';

import { FeedbackFieldTypes } from 'types/wizard-form';

const Page: React.FC<{
  title: string;
  onPrevious: () => void;
  handleSubmit: (event: React.FormEvent<HTMLFormElement>) => void;
  questions: {
    id: string;
    type: FeedbackFieldTypes;
    required?: boolean;
    question: string;
    description?: string;
    answers: string[];
    customAnswer?: {
      id: string;
      label: string;
    };
  }[];
  previousButton?: string;
  nextButton?: string;
  submitButton: string;
  isLastPage: boolean;
  isFirstPage: boolean;
  formValues: object;
  errorMessage?: string;
}> = (props) => {
  const {
    title,
    questions,
    onPrevious,
    handleSubmit,
    isFirstPage,
    isLastPage,
    previousButton,
    nextButton,
    submitButton,
    formValues,
    errorMessage,
  } = props;

  const getAnswerComponent = (type) => {
    switch (type) {
      case FeedbackFieldTypes.Boolean:
        return Boolean;
      case FeedbackFieldTypes.Single:
        return Single;
      case FeedbackFieldTypes.Multiple:
        return Multiple;
      case FeedbackFieldTypes.FreeAnswer:
        return FreeAnswer;
      case FeedbackFieldTypes.Rating:
        return Rating;
      default:
        return null;
    }
  };

  return (
    <>
      <form onSubmit={handleSubmit}>
        <div className="m-wizard-form__form-content">
          {!isFirstPage && title && (
            <div className="m-wizard-form__form-content-title">
              <h3>{title}</h3>
            </div>
          )}

          {questions.map((question) => {
            const { id, type } = question;
            const AnswerComponent = getAnswerComponent(type);

            return <AnswerComponent key={id} {...question} formValues={formValues} />;
          })}
        </div>
        {errorMessage && <ErrorMessage touched={true} error={errorMessage} />}
        <div className="m-wizard-form__form-footer">
          {!isFirstPage && (
            <button
              className="m-wizard-form__button m-wizard-form__button--previous"
              type="button"
              onClick={onPrevious}
            >
              {previousButton || <T _str="Previous" />}
            </button>
          )}
          <button
            className={cx('m-wizard-form__button', {
              'm-wizard-form__button--next': !isLastPage,
              'm-wizard-form__button--submit': isLastPage,
            })}
            type="submit"
          >
            {isLastPage ? submitButton || <T _str="Submit" /> : nextButton || <T _str="Next" />}
          </button>
        </div>
      </form>
    </>
  );
};

export default Page;
