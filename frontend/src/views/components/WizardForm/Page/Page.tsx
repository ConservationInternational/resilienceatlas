import React from 'react';
import cx from 'classnames';
import { T } from '@transifex/react';
import { useFormContext } from 'react-hook-form';

import BooleanField from 'views/components/WizardForm/FieldTypes/Boolean';
import Single from 'views/components/WizardForm/FieldTypes/Single';
import Multiple from 'views/components/WizardForm/FieldTypes/Multiple';
import FreeAnswer from 'views/components/WizardForm/FieldTypes/FreeAnswer';
import Rating from 'views/components/WizardForm/FieldTypes/Rating';

import ErrorMessage from 'views/components/WizardForm/ErrorMessage';

import { FeedbackFieldTypes } from 'types/wizard-form';

export interface Answer {
  id: string;
  label: string;
  labelRaw?: string;
  value?: boolean | string;
}

interface PageProps {
  title: string;
  onPrevious?: () => void;
  questions: {
    id: string;
    type: FeedbackFieldTypes;
    required?: boolean;
    question: string;
    questionRaw?: string;
    description?: string;
    answers?: Answer[];
    customAnswer?: {
      id: string;
      label: string;
    };
  }[];
  previousButton?: string;
  nextButton?: string;
  submitButton?: string;
  isLastPage?: boolean;
  isFirstPage?: boolean;
  formValues?: Record<string, unknown>;
  errorMessage?: string;
}

const Page: React.FC<PageProps> = (props) => {
  const {
    title,
    questions,
    onPrevious,
    isFirstPage,
    isLastPage,
    previousButton,
    nextButton,
    submitButton,
    errorMessage,
  } = props;

  const { watch } = useFormContext();
  const formValues = watch();

  const getAnswerComponent = (type: FeedbackFieldTypes) => {
    switch (type) {
      case FeedbackFieldTypes.Boolean:
        return BooleanField;
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
      <div className="m-wizard-form__form-content">
        {!isFirstPage && title && (
          <div className="m-wizard-form__form-content-title">
            <h3>{title}</h3>
          </div>
        )}

        {questions.map((question) => {
          const { id, type } = question;
          const AnswerComponent = getAnswerComponent(type);

          if (!AnswerComponent) return null;

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
    </>
  );
};

export default Page;
