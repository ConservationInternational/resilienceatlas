import React, { useState, useEffect } from 'react';
import { Field } from 'redux-form';

import Section from 'views/components/WizardForm/Section';
import ErrorMessage from 'views/components/WizardForm/ErrorMessage';

const Input = (props) => {
  const { input, meta, onError } = props;

  useEffect(() => {
    const { touched, error } = meta;
    onError(touched && error);
  }, [meta, onError]);

  return (
    <>
      <input type="text" {...input} />
      <ErrorMessage {...meta} />
    </>
  );
};

const FreeAnswer = (props) => {
  const { id: name } = props;

  const [hasError, setHasError] = useState(false);

  return (
    <Section error={hasError} {...props}>
      <Field component={Input} name={name} onError={setHasError} />
    </Section>
  );
};

export default FreeAnswer;
