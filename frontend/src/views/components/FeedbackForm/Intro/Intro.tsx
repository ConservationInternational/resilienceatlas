import React from 'react';
import { compose } from 'redux';
import { connect } from 'react-redux';
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

export default compose(
  reduxForm({
    form: 'Feedback',
    destroyOnUnmount: false,
    forceUnregisterOnUnmount: true,
    asyncValidate: asyncValidate(IntroSchema),
  }),
  connect((state) => ({
    formValues: state['form']['Feedback']?.values,
  })),
)(Intro) as React.ComponentType;
