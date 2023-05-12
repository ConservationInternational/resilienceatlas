import React, { useMemo } from 'react';
import Page from 'views/components/WizardForm/Page';
import { useLocale } from '@transifex/react';
import { getIntro } from 'constants/feedback-questions';

const Intro = (props) => {
  const { handleSubmit, ...rest } = props;
  // Use transifex locale here instead of next as the content is translated with the transifex native component
  const locale = useLocale();

  // eslint-disable-next-line react-hooks/exhaustive-deps
  const intro = useMemo(() => getIntro(), [locale]);
  const { title, nextButton, questions } = intro;

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
