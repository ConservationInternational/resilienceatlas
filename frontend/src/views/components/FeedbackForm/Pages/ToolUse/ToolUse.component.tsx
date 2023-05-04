import React, { useMemo } from 'react';
import { useRouter } from 'next/router';
import Page from 'views/components/WizardForm/Page';

import { getToolUse } from 'constants/feedback-questions';

const ToolUse = (props) => {
  const { handleSubmit, ...rest } = props;
  const { locale } = useRouter();
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
