import React, { useMemo } from 'react';

import Page from 'views/components/WizardForm/Page';
import { useRouter } from 'next/router';
import { getWebsite } from 'constants/feedback-questions';

const Website = (props) => {
  const { handleSubmit, ...rest } = props;
  const { locale } = useRouter();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  const website = useMemo(() => getWebsite(), [locale]);

  const { title, previousButton, questions } = website;

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
