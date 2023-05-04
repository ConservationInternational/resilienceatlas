import React, { useState } from 'react';
import { connect } from 'react-redux';
import { reset } from 'redux-form';
import { useRouter } from 'next/router';
import { T } from '@transifex/react';

import WizardForm from 'views/components/WizardForm/WizardForm.component';
import Intro from './Pages/Intro';
import ToolUse from './Pages/ToolUse';
import Map from './Pages/Map';
import Website from './Pages/Website';
import Outro from './Outro/Outro';

import { processFeedbackForm, submitFeedback } from 'state/modules/feedback';

const FeedbackForm = ({ resetForm }) => {
  const [submitted, setSubmitted] = useState(false);
  const [error, setError] = useState(null);

  const { query } = useRouter();
  const { returnPath, returnText } = query;

  const handleSubmit = (values) => {
    setError(null);

    const feedbackData = processFeedbackForm(values);

    submitFeedback(feedbackData)
      .then(() => {
        setSubmitted(true);
        resetForm();
      })
      .catch(() => setError('There was an error submitting your form.'));
  };

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
      errorMessage={error}
    >
      <Intro />
      <ToolUse />
      <Map />
      <Website />
    </WizardForm>
  );
};

const mapDispatchToProps = (dispatch) => {
  return {
    resetForm: () => dispatch(reset('Feedback')),
  };
};

export default connect(null, mapDispatchToProps)(FeedbackForm);
