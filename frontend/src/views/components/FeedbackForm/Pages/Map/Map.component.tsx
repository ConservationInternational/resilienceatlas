import React, { useMemo } from 'react';

import Page from 'views/components/WizardForm/Page';
import { useLocale } from '@transifex/react';
import { getMap } from 'constants/feedback-questions';

const Map = (props) => {
  const { handleSubmit, ...rest } = props;
  // Use transifex locale here instead of next as the content is translated with the transifex native component
  const locale = useLocale();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  const translatedMap = useMemo(() => getMap(), [locale]);
  const { title, previousButton, nextButton, questions } = translatedMap;

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
