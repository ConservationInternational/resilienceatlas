import React from 'react';
import { Field } from 'redux-form';

import ErrorMessage from 'views/components/WizardForm/ErrorMessage';

const RadioGroup = (props) => {
  const { input, meta, answers, customAnswer } = props;
  const { name } = input;

  const acceptCustomAnswer = customAnswer?.id && customAnswer?.label;

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
        <div className="checkbox">
          <label>
            <input type="radio" {...input} name={name} value={customAnswer.id} />
            {customAnswer.label}
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
          </label>
        </div>
      )}
      <ErrorMessage {...meta} />
    </>
  );
};

const Single = (props) => {
  const { id: name, answers, customAnswer, formValues } = props;
  return (
    <Field
      component={RadioGroup}
      name={name}
      answers={answers}
      formValues={formValues}
      customAnswer={customAnswer}
    />
  );
};

export default Single;
