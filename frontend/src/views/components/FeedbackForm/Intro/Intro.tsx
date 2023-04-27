import React from 'react';
import { reduxForm } from 'redux-form';

import { IntroSchema } from 'state/modules/feedback';
import { INTRO } from 'constants/feedback-questions';

import { asyncValidate } from 'views/utils/asyncValidate';

import Page from 'views/components/WizardForm/Page';

const Intro = (props) => {
  const { handleSubmit, ...rest } = props;
  const { title, nextButton, questions } = INTRO;

  return (
    <Page
      title={title}
      questions={questions}
      nextButton={nextButton}
      handleSubmit={handleSubmit}
      {...rest}
    />
  );
};

export default reduxForm({
  form: 'Feedback',
  destroyOnUnmount: false,
  forceUnregisterOnUnmount: true,
  asyncValidate: asyncValidate(IntroSchema),
})(Intro);
