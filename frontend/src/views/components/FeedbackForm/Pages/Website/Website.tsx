import React, { useMemo } from 'react';

import Page from 'views/components/WizardForm/Page';
import { useLocale } from '@transifex/react';
import { getWebsite } from 'constants/feedback-questions';

interface WebsiteProps {
  onPrevious?: () => void;
  isFirstPage?: boolean;
  isLastPage?: boolean;
  submitButton?: string;
  errorMessage?: string;
}

const Website: React.FC<WebsiteProps> = (props) => {
  // Use transifex locale here instead of next as the content is translated with the transifex native component
  const locale = useLocale();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  const website = useMemo(() => getWebsite(), [locale]);

  const { title, previousButton, questions } = website;

  return <Page title={title} questions={questions} previousButton={previousButton} {...props} />;
};

export default Website;
