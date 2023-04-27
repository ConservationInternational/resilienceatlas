import React from 'react';
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

export default reduxForm({
  form: 'Feedback',
  destroyOnUnmount: false,
  forceUnregisterOnUnmount: true,
  asyncValidate: asyncValidate(MapSchema),
})(Map);
