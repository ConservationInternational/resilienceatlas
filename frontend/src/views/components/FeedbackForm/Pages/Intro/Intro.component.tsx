import React from 'react';

import Page from 'views/components/WizardForm/Page';

import { INTRO } from 'constants/feedback-questions';

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

export default Intro;
