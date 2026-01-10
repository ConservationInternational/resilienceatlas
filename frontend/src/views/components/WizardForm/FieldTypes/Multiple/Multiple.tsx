import React, { useState, useEffect } from 'react';
import { useFormContext, Controller } from 'react-hook-form';

import Section from 'views/components/WizardForm/Section';
import ErrorMessage from 'views/components/WizardForm/ErrorMessage';
import type { Answer } from 'views/components/WizardForm/Page/Page';

interface CustomAnswer {
  id: string;
  label: string;
}

interface MultipleProps {
  id: string;
  question: string;
  description?: string;
  required?: boolean;
  answers?: Answer[];
  customAnswer?: CustomAnswer;
  formValues?: Record<string, unknown>;
}

const Multiple: React.FC<MultipleProps> = (props) => {
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
  const groupErrorId = `checkbox-group-error-${name}`;

  return (
    <Section error={hasError} {...props}>
      <Controller
        name={name}
        control={control}
        defaultValue={[]}
        render={({ field, fieldState }) => {
          const handleCheckboxChange = (answerId: string, checked: boolean) => {
            const currentValue = Array.isArray(field.value) ? field.value : [];
            let newValue: string[];

            if (checked) {
              newValue = [...currentValue, answerId];
            } else {
              newValue = currentValue.filter((id: string) => id !== answerId);
            }

            field.onChange(newValue.length > 0 ? newValue : undefined);
          };

          const currentValue = Array.isArray(field.value) ? field.value : [];

          return (
            <>
              {answers.map((answer, index) => (
                <div className="checkbox" key={index}>
                  <input
                    type="checkbox"
                    id={`${name}-${answer.id}`}
                    value={answer.id}
                    checked={currentValue.includes(answer.id)}
                    onChange={(e) => handleCheckboxChange(answer.id, e.target.checked)}
                  />
                  <label htmlFor={`${name}-${answer.id}`}>{answer.label}</label>
                </div>
              ))}
              {acceptCustomAnswer && (
                <div className="checkbox">
                  <input
                    type="checkbox"
                    id={`${name}-${customAnswer.id}`}
                    checked={currentValue.includes(customAnswer.id)}
                    onChange={(e) => handleCheckboxChange(customAnswer.id, e.target.checked)}
                  />
                  <label htmlFor={`${name}-${customAnswer.id}`}>
                    {customAnswer.label}
                    <input type="text" {...register(customAnswer.id)} />
                  </label>
                </div>
              )}
              <ErrorMessage
                id={groupErrorId}
                touched={fieldState.isTouched}
                error={fieldState.error?.message}
              />
            </>
          );
        }}
      />
    </Section>
  );
};

export default Multiple;
