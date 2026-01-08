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

const CheckboxGroup = (props) => {
  const { answers, input, meta, customAnswer, onError } = props;
  const { name } = input;

  useEffect(() => {
    const { touched, error } = meta;
    onError(touched && error);
  }, [meta, onError]);

  const handleAnswerCheckboxClick = (event, id) => {
    let newValue = [...input.value];

    if (event.target.checked) {
      newValue.push(id);
    } else {
      newValue.splice(newValue.indexOf(id), 1);
    }

    if (Array.isArray(newValue) && !newValue.length) {
      newValue = undefined;
    }

    return input.onChange(newValue);
  };

  const acceptCustomAnswer = customAnswer?.id && customAnswer?.label;
  const groupErrorId = `checkbox-group-error-${name}`;

  return (
    <>
      {answers.map((answer, index) => (
        <div className="checkbox" key={index}>
          <input
            type="checkbox"
            name={`${name}[${index}]`}
            id={`${name}-${answer.id}`}
            value={answer.id}
            checked={input.value.indexOf(answer.id) !== -1}
            onChange={(event) => handleAnswerCheckboxClick(event, answer.id)}
          />
          <label htmlFor={`${name}-${answer.id}`}>{answer.label}</label>
        </div>
      ))}
      {acceptCustomAnswer && (
        <div className="checkbox">
          <input
            type="checkbox"
            id={`${name}-${customAnswer.id}`}
            name={customAnswer.id}
            onChange={(event) => handleAnswerCheckboxClick(event, customAnswer.id)}
          />
          <label htmlFor={`${name}-${customAnswer.id}`}>
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

const Multiple = (props) => {
  const { id: name, answers, customAnswer, formValues } = props;

  const [hasError, setHasError] = useState(false);

  return (
    <Section error={hasError} {...props}>
      <Field
        component={CheckboxGroup}
        name={name}
        answers={answers}
        formValues={formValues}
        customAnswer={customAnswer}
        onError={setHasError}
      />
    </Section>
  );
};

export default Multiple;
