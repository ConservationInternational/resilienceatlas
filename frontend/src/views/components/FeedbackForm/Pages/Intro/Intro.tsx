import React, { useMemo } from 'react';
import Page from 'views/components/WizardForm/Page';
import { useLocale } from '@transifex/react';
import { getIntro } from 'constants/feedback-questions';

interface IntroProps {
  onPrevious?: () => void;
  isFirstPage?: boolean;
  isLastPage?: boolean;
  submitButton?: string;
  errorMessage?: string;
}

const Intro: React.FC<IntroProps> = (props) => {
  // Use transifex locale here instead of next as the content is translated with the transifex native component
  const locale = useLocale();

  // eslint-disable-next-line react-hooks/exhaustive-deps
  const intro = useMemo(() => getIntro(), [locale]);
  const { title, nextButton, questions } = intro;

  return <Page title={title} questions={questions} nextButton={nextButton} {...props} />;
};

export default Intro;
