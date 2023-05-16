import React, { useState, useEffect } from 'react';
import { Field } from 'redux-form';

import Section from 'views/components/WizardForm/Section';
import ErrorMessage from 'views/components/WizardForm/ErrorMessage';

const InputField = (props) => {
  const { input, meta, groupErrorId } = props;
  const { active } = meta || {};

  return (
    <>
      <input
        ref={(input) => {
          if (!active) return;
          input?.focus();
        }}
        type="text"
        {...input}
      />
      <ErrorMessage targetId={groupErrorId} {...meta} />
    </>
  );
};

const RadioGroup = (props) => {
  const { input, meta, answers, customAnswer, onError } = props;
  const { name } = input;

  useEffect(() => {
    const { touched, error } = meta;
    onError(touched && error);
  }, [meta, onError]);

  const acceptCustomAnswer = customAnswer?.id && customAnswer?.label;
  const groupErrorId = `radio-group-error-${name}`;
  return (
    <>
      {answers.map((answer) => (
        <div key={answer.id}>
          <input
            type="radio"
            {...input}
            id={`${input.name}-${answer.id}`}
            value={answer.id}
            checked={answer.id === input.value}
          />
          <label htmlFor={`${input.name}-${answer.id}`}>{answer.label}</label>
        </div>
      ))}
      {acceptCustomAnswer && (
        <div className="checkbox">
          <input
            type="radio"
            {...input}
            id={`${input.name}-${customAnswer.id}`}
            name={name}
            value={customAnswer.id}
          />
          <label htmlFor={`${input.name}-${customAnswer.id}`}>
            {customAnswer.label}
            <Field
              name={customAnswer.id}
              component={(props) => <InputField {...props} groupErrorId={groupErrorId} />}
            />
          </label>
        </div>
      )}
      <ErrorMessage id={groupErrorId} {...meta} />
    </>
  );
};

const Single = (props) => {
  const { id: name, answers, customAnswer, formValues } = props;

  const [hasError, setHasError] = useState(false);

  return (
    <Section error={hasError} {...props}>
      <Field
        component={RadioGroup}
        name={name}
        answers={answers}
        formValues={formValues}
        customAnswer={customAnswer}
        onError={setHasError}
      />
    </Section>
  );
};

export default Single;
