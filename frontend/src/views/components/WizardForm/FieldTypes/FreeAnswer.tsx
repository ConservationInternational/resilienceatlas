import React from 'react';
import { Field } from 'redux-form';

import Section from 'views/components/WizardForm/Section';
import ErrorMessage from 'views/components/WizardForm/ErrorMessage';

const Input = (props) => {
  const { input, meta } = props;

  return (
    <>
      <input type="text" {...input} />
      <ErrorMessage {...meta} />
    </>
  );
};

const FreeAnswer = (props) => {
  const { id: name } = props;

  return (
    <Section {...props}>
      <Field component={Input} name={name} />
    </Section>
  );
};

export default FreeAnswer;
