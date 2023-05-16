import React, { useMemo } from 'react';
import { useLocale } from '@transifex/react';
import Page from 'views/components/WizardForm/Page';

import { getToolUse } from 'constants/feedback-questions';

const ToolUse = (props) => {
  const { handleSubmit, ...rest } = props;
  // Use transifex locale here instead of next as the content is translated with the transifex native component
  const locale = useLocale();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  const toolUse = useMemo(() => getToolUse(), [locale]);
  const { title, previousButton, nextButton, questions } = toolUse;

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
