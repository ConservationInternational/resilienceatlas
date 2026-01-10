import React, { useState, useEffect } from 'react';
import { useFormContext, Controller } from 'react-hook-form';

import Section from 'views/components/WizardForm/Section';
import ErrorMessage from 'views/components/WizardForm/ErrorMessage';
import type { Answer } from 'views/components/WizardForm/Page/Page';

interface BooleanFieldProps {
  id: string;
  question: string;
  description?: string;
  required?: boolean;
  answers?: Answer[];
  formValues?: Record<string, unknown>;
}

const BooleanField: React.FC<BooleanFieldProps> = (props) => {
  const { id: name, answers = [] } = props;
  const {
    control,
    formState: { errors },
  } = useFormContext();

  const [hasError, setHasError] = useState(false);

  useEffect(() => {
    const fieldError = errors[name];
    setHasError(!!fieldError);
  }, [errors, name]);

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
                  value={String(answer.value)}
                  checked={String(answer.value) === String(field.value)}
                  onChange={(e) => field.onChange(e.target.value === 'true')}
                />
                <label htmlFor={`${name}-${answer.id}`}>{answer.label}</label>
              </div>
            ))}
            <ErrorMessage touched={fieldState.isTouched} error={fieldState.error?.message} />
          </>
        )}
      />
    </Section>
  );
};

export default BooleanField;
