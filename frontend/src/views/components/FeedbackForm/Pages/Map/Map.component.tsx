import React, { useMemo } from 'react';

import Page from 'views/components/WizardForm/Page';
import { useRouter } from 'next/router';
import { getMap } from 'constants/feedback-questions';

const Map = (props) => {
  const { handleSubmit, ...rest } = props;
  const { locale } = useRouter();
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
