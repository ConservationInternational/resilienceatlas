import React, { useState, useEffect } from 'react';
import { useFormContext, Controller } from 'react-hook-form';

import Section from 'views/components/WizardForm/Section';
import ErrorMessage from 'views/components/WizardForm/ErrorMessage';
import type { Answer } from 'views/components/WizardForm/Page/Page';

interface CustomAnswer {
  id: string;
  label: string;
}

interface SingleProps {
  id: string;
  question: string;
  description?: string;
  required?: boolean;
  answers?: Answer[];
  customAnswer?: CustomAnswer;
  formValues?: Record<string, unknown>;
}

const Single: React.FC<SingleProps> = (props) => {
  const { id: name, answers = [], customAnswer } = props;
  const {
    control,
    formState: { errors },
    register,
  } = useFormContext();

  const [hasError, setHasError] = useState(false);

  useEffect(() => {
    const fieldError = errors[name];
    setHasError(Boolean(fieldError));
  }, [errors, name]);

  const acceptCustomAnswer = customAnswer?.id && customAnswer?.label;
  const groupErrorId = `radio-group-error-${name}`;

  return (
    <Section error={hasError} {...props}>
      <Controller
        name={name}
        control={control}
        render={({ field, fieldState }) => (
          <>
            {answers.map((answer) => (
              <div key={answer.id}>
                <input
                  type="radio"
                  id={`${name}-${answer.id}`}
                  value={answer.id}
                  checked={answer.id === field.value}
                  onChange={() => field.onChange(answer.id)}
                />
                <label htmlFor={`${name}-${answer.id}`}>{answer.label}</label>
              </div>
            ))}
            {acceptCustomAnswer && (
              <div className="checkbox">
                <input
                  type="radio"
                  id={`${name}-${customAnswer.id}`}
                  value={customAnswer.id}
                  checked={customAnswer.id === field.value}
                  onChange={() => field.onChange(customAnswer.id)}
                />
                <label htmlFor={`${name}-${customAnswer.id}`}>
                  {customAnswer.label}
                  <input
                    type="text"
                    {...register(customAnswer.id)}
                    onFocus={() => field.onChange(customAnswer.id)}
                  />
                </label>
              </div>
            )}
            <ErrorMessage
              id={groupErrorId}
              touched={fieldState.isTouched}
              error={fieldState.error?.message}
            />
          </>
        )}
      />
    </Section>
  );
};

export default Single;
