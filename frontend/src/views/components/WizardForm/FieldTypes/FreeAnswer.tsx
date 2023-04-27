import React from 'react';
import { Field } from 'redux-form';

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
  return <Field component={Input} name={name} />;
};

export default FreeAnswer;
