import React from 'react';
import { Field } from 'redux-form';

import ErrorMessage from 'views/components/WizardForm/ErrorMessage';

const RadioGroup = (props) => {
  const { input, meta, answers } = props;

  return (
    <>
      {answers.map((answer) => (
        <div key={answer.id}>
          <label key={answer.id}>
            <input
              type="radio"
              {...input}
              value={answer.value}
              checked={answer.value === input.value}
            />
            {answer.label}
          </label>
        </div>
      ))}
      <ErrorMessage {...meta} />
    </>
  );
};

const Boolean = (props) => {
  const { id: name, answers } = props;

  const normalize = (value) => value === 'true';

  return <Field component={RadioGroup} name={name} answers={answers} normalize={normalize} />;
};

export default Boolean;
