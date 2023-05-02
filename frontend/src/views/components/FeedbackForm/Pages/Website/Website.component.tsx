import React from 'react';

import Page from 'views/components/WizardForm/Page';

import { WEBSITE } from 'constants/feedback-questions';

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

export default Website;
