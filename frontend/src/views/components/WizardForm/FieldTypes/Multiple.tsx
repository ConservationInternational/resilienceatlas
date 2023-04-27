import React from 'react';
import { Field } from 'redux-form';

import ErrorMessage from 'views/components/WizardForm/ErrorMessage';

const CheckboxGroup = (props) => {
  const { name, answers, input, meta } = props;

  return (
    <>
      {answers.map((answer, index) => (
        <div className="checkbox" key={index}>
          <label>
            <input
              type="checkbox"
              name={`${name}[${index}]`}
              value={answer.id}
              checked={input.value.indexOf(answer.id) !== -1}
              onChange={(event) => {
                let newValue = [...input.value];

                if (event.target.checked) {
                  newValue.push(answer.id);
                } else {
                  newValue.splice(newValue.indexOf(answer.id), 1);
                }

                if (Array.isArray(newValue) && !newValue.length) {
                  newValue = undefined;
                }

                return input.onChange(newValue);
              }}
            />
            {answer.label}
          </label>
        </div>
      ))}
      <ErrorMessage {...meta} />
    </>
  );
};

const Multiple = (props) => {
  const { id: name, answers } = props;

  return <Field component={CheckboxGroup} name={name} answers={answers} />;
};

export default Multiple;
