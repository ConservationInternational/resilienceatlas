import React from 'react';
import { compose } from 'redux';
import { connect } from 'react-redux';
import { reduxForm } from 'redux-form';

import { WebsiteSchema } from 'state/modules/feedback';
import { WEBSITE } from 'constants/feedback-questions';

import { asyncValidate } from 'views/utils/asyncValidate';

import Page from 'views/components/WizardForm/Page';

const Website = (props) => {
  const { handleSubmit, ...rest } = props;
  const { title, previousButton, questions } = WEBSITE;

  return (
    <Page
      title={title}
      questions={questions}
      previousButton={previousButton}
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
    asyncValidate: asyncValidate(WebsiteSchema),
  }),
  connect((state) => ({
    formValues: state['form']['Feedback']?.values,
  })),
)(Website) as React.ComponentType;
