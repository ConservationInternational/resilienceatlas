import React from 'react';
import { Field } from 'redux-form';

import ErrorMessage from 'views/components/WizardForm/ErrorMessage';

const RadioGroup = (props) => {
  const { input, meta, answers } = props;

  return (
    <>
      {answers.map((answer) => (
        <div key={answer.id}>
          <label key={answer.value}>
            <input type="radio" {...input} value={answer.id} checked={answer.id === input.value} />
            {answer.label}
          </label>
        </div>
      ))}
      <ErrorMessage {...meta} />
    </>
  );
};

const Single = (props) => {
  const { id: name, answers } = props;
  return <Field component={RadioGroup} name={name} answers={answers} />;
};

export default Single;
