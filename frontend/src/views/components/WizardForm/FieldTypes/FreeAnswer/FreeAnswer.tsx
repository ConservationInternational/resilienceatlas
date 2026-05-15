import React, { useState, useEffect } from 'react';
import { useFormContext, Controller } from 'react-hook-form';

import Section from 'views/components/WizardForm/Section';
import ErrorMessage from 'views/components/WizardForm/ErrorMessage';

interface FreeAnswerProps {
  id: string;
  question: string;
  description?: string;
  required?: boolean;
}

const FreeAnswer: React.FC<FreeAnswerProps> = (props) => {
  const { id: name } = props;
  const {
    control,
    formState: { errors },
  } = useFormContext();

  const [hasError, setHasError] = useState(false);

  useEffect(() => {
    const fieldError = errors[name];
    setHasError(Boolean(fieldError));
  }, [errors, name]);

  return (
    <Section error={hasError} {...props}>
      <Controller
        name={name}
        control={control}
        render={({ field, fieldState }) => (
          <>
            <input type="text" {...field} value={field.value || ''} />
            <ErrorMessage touched={fieldState.isTouched} error={fieldState.error?.message} />
          </>
        )}
      />
    </Section>
  );
};

export default FreeAnswer;
