import React from 'react';

import Boolean from 'views/components/WizardForm/FieldTypes/Boolean';
import Single from 'views/components/WizardForm/FieldTypes/Single';
import Multiple from 'views/components/WizardForm/FieldTypes/Multiple';
import FreeAnswer from 'views/components/WizardForm/FieldTypes/FreeAnswer';
import Rating from 'views/components/WizardForm/FieldTypes/Rating';

import { FeedbackFieldTypes } from 'types/wizard-form.d';

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
        <div className="m-wizard-form__form-footer">
          {!isFirstPage && (
            <button className="btn btn-primary" type="button" onClick={onPrevious}>
              {previousButton || 'Previous'}
            </button>
          )}
          <button className="btn btn-primary" type="submit">
            {isLastPage ? submitButton || 'Submit' : nextButton || 'Next'}
          </button>
        </div>
      </form>
    </>
  );
};

export default Page;
