import React from 'react';

import Page from 'views/components/WizardForm/Page';

import { MAP } from 'constants/feedback-questions';

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

export default Map;
