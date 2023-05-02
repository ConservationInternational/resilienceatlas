import React, { useState } from 'react';
import { useRouter } from 'next/router';

import WizardForm from 'views/components/WizardForm/WizardForm.component';

import Intro from './Pages/Intro';
import ToolUse from './Pages/ToolUse';
import Map from './Pages/Map';
import Website from './Pages/Website';

import Outro from 'views/components/FeedbackForm/Outro/Outro';

const FeedbackForm = () => {
  const [submitted, setSubmitted] = useState(false);

  const { query } = useRouter();
  const { returnPath, returnText } = query;

  const handleSubmit = (values) => {
    // TODO Simao: Process values and make API query
    console.log(values);
    setSubmitted(true);
  };

  return (
    <WizardForm
      title="Resilience Atlas"
      subtitle="User survey"
      description="Thank you for taking the Resilience Atlas survey. We are collecting feedback from users of the Resilience Atlas to improve our site functionality and to better provide the resources that you need in order to use this tool."
      onSubmit={handleSubmit}
      formSubmitted={submitted}
      outroComponent={Outro}
      backBtnPath={returnPath as string}
      backBtnText={returnText as string}
    >
      <Intro />
      <ToolUse />
      <Map />
      <Website />
    </WizardForm>
  );
};

export default FeedbackForm;
