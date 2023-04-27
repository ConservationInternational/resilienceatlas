import React from 'react';
import { compose } from 'redux';
import { connect } from 'react-redux';
import { reduxForm } from 'redux-form';

import { MapSchema } from 'state/modules/feedback';
import { MAP } from 'constants/feedback-questions';

import { asyncValidate } from 'views/utils/asyncValidate';

import Page from 'views/components/WizardForm/Page';

const Map = (props) => {
  const { handleSubmit, ...rest } = props;
  const { title, previousButton, nextButton, questions } = MAP;

  return (
    <Page
      title={title}
      questions={questions}
      previousButton={previousButton}
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
    asyncValidate: asyncValidate(MapSchema),
  }),
  connect((state) => ({
    formValues: state['form']['Feedback']?.values,
  })),
)(Map) as React.ComponentType;
