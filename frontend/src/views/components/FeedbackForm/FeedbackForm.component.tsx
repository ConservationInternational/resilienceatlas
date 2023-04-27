import React from 'react';

import WizardForm from 'views/components/WizardForm/WizardForm.component';

import Intro from 'views/components/FeedbackForm/Intro/Intro';
import ToolUse from 'views/components/FeedbackForm/ToolUse/ToolUse';
import Map from 'views/components/FeedbackForm/Map/Map';
import Website from 'views/components/FeedbackForm/Website/Website';

const FeedbackForm = () => {
  const handleSubmit = (values) => {
    // TODO Simao: Process values and make API query
    console.log(values);
  };

  return (
    <WizardForm
      title="Resilience Atlas"
      subtitle="User survey"
      description="Thank you for taking the Resilience Atlas survey. We are collecting feedback from users of the Resilience Atlas to improve our site functionality and to better provide the resources that you need in order to use this tool."
      onSubmit={handleSubmit}
    >
      <Intro />
      <ToolUse />
      <Map />
      <Website />
    </WizardForm>
  );
};

export default FeedbackForm;
