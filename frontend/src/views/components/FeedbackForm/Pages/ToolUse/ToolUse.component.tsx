import React from 'react';

import Page from 'views/components/WizardForm/Page';

import { TOOL_USE } from 'constants/feedback-questions';

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

export default ToolUse;
