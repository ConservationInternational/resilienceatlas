import React, { useState, useEffect } from 'react';
import { Field } from 'redux-form';

import Section from 'views/components/WizardForm/Section';
import ErrorMessage from 'views/components/WizardForm/ErrorMessage';

const RadioGroup = (props) => {
  const { input, meta, answers, customAnswer, onError } = props;
  const { name } = input;

  useEffect(() => {
    const { touched, error } = meta;
    onError(touched && error);
  }, [meta, onError]);

  const acceptCustomAnswer = customAnswer?.id && customAnswer?.label;

  // TODO Simao improve errors

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
      {acceptCustomAnswer && (
        <div className="m-wizard-form__custom-answer">
          <label>
            <input type="radio" {...input} name={name} value={customAnswer.id} />
            {customAnswer.label}
          </label>
          <Field
            name={customAnswer.id}
            component={(customProps) => {
              const { input: customInput, meta: customInputMeta } = customProps;
              return (
                <>
                  <input
                    ref={(input) => {
                      if (!customInputMeta?.active) return;
                      input?.focus();
                    }}
                    type="text"
                    {...customInput}
                  />
                  <ErrorMessage {...customInputMeta} />
                </>
              );
            }}
          />
        </div>
      )}
      <ErrorMessage {...meta} />
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
