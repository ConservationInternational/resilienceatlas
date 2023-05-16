import React, { useState, useEffect } from 'react';
import { Field } from 'redux-form';

import Section from 'views/components/WizardForm/Section';
import ErrorMessage from 'views/components/WizardForm/ErrorMessage';

const RadioGroup = (props) => {
  const { input, meta, answers, onError } = props;

  useEffect(() => {
    const { touched, error } = meta;
    onError(touched && error);
  }, [meta, onError]);

  return (
    <>
      {answers.map((answer) => (
        <div key={answer.id}>
          <input
            type="radio"
            {...input}
            id={`${input.name}-${answer.id}`}
            value={answer.value}
            checked={answer.value === input.value}
          />
          <label htmlFor={`${input.name}-${answer.id}`}>{answer.label}</label>
        </div>
      ))}
      <ErrorMessage {...meta} />
    </>
  );
};

const Boolean = (props) => {
  const { id: name, answers } = props;

  const [hasError, setHasError] = useState(false);

  const normalize = (value) => value === 'true';

  return (
    <Section error={hasError} {...props}>
      <Field
        component={RadioGroup}
        name={name}
        answers={answers}
        normalize={normalize}
        onError={setHasError}
      />
    </Section>
  );
};

export default Boolean;
