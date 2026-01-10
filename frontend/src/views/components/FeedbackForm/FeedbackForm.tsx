import React, { useState } from 'react';
import { useRouter } from 'next/router';
import { T } from '@transifex/react';

import WizardForm from 'views/components/WizardForm';
import Intro from './Pages/Intro';
import ToolUse from './Pages/ToolUse';
import Map from './Pages/Map';
import Website from './Pages/Website';
import Outro from './Outro/Outro';

import {
  processFeedbackForm,
  submitFeedback,
  IntroSchema,
  ToolUseSchema,
  MapSchema,
  WebsiteSchema,
} from 'state/modules/feedback';

const FeedbackForm = () => {
  const [submitted, setSubmitted] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const { locale } = useRouter();
  const { query } = useRouter();
  const { returnPath, returnText } = query;

  const handleSubmit = (values: Record<string, unknown>) => {
    setError(null);

    const feedbackData = processFeedbackForm(values, locale);

    submitFeedback(feedbackData)
      .then(() => {
        setSubmitted(true);
      })
      .catch(() => setError('There was an error submitting your form.'));
  };

  // Validation schemas for each page
  const validationSchemas = [IntroSchema, ToolUseSchema, MapSchema, WebsiteSchema];

  return (
    <WizardForm
      title={<T _str="Resilience Atlas" />}
      subtitle={<T _str="User survey" />}
      description={
        <T _str="Thank you for taking the Resilience Atlas survey. We are collecting feedback from users of the Resilience Atlas to improve our site functionality and to better provide the resources that you need in order to use this tool." />
      }
      onSubmit={handleSubmit}
      formSubmitted={submitted}
      outroComponent={Outro}
      backBtnPath={Array.isArray(returnPath) ? returnPath.join() : returnPath}
      backBtnText={Array.isArray(returnText) ? returnText.join() : returnText}
      errorMessage={error ?? undefined}
      validationSchemas={validationSchemas}
    >
      <Intro />
      <ToolUse />
      <Map />
      <Website />
    </WizardForm>
  );
};

export default FeedbackForm;
