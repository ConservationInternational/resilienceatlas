import React from 'react';
import { reduxForm } from 'redux-form';

import { ToolUseSchema } from 'state/modules/feedback';
import { TOOL_USE } from 'constants/feedback-questions';

import { asyncValidate } from 'views/utils/asyncValidate';

import Page from 'views/components/WizardForm/Page';

const ToolUse = (props) => {
  const { handleSubmit, ...rest } = props;
  const { title, previousButton, nextButton, questions } = TOOL_USE;

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
  asyncValidate: asyncValidate(ToolUseSchema),
})(ToolUse);
