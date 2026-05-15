import React, { useMemo, useEffect } from 'react';
import { useFormContext, useFieldArray } from 'react-hook-form';
import { t } from '@transifex/native';
import { useRouter } from 'next/router';
import Section from 'views/components/WizardForm/Section';
import type { Answer } from 'views/components/WizardForm/Page/Page';

interface RatingProps {
  id: string;
  question: string;
  description?: string;
  required?: boolean;
  answers?: Answer[];
  formValues?: Record<string, unknown>;
}

const getRatings = () => [
  {
    id: 1,
    label: '1',
    description: t('Strongly Disagree'),
  },
  {
    id: 2,
    label: '2',
  },
  {
    id: 3,
    label: '3',
    description: t('Neutral'),
  },
  {
    id: 4,
    label: '4',
  },
  {
    id: 5,
    label: '5',
    description: t('Strongly Agree'),
  },
];

const Rating: React.FC<RatingProps> = (props) => {
  const { id: name, answers = [] } = props;
  const { locale } = useRouter();
  const { control, setValue, watch } = useFormContext();

  // eslint-disable-next-line react-hooks/exhaustive-deps
  const ratings = useMemo(() => getRatings(), [locale]);

  const { fields, append } = useFieldArray({
    control,
    name,
  });

  // Initialize field array with answers
  useEffect(() => {
    if (fields.length >= answers.length) return;

    answers.forEach(({ id }) => {
      append({ [id]: null });
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const watchFieldArray = watch(name);

  return (
    <Section {...props}>
      <table className="m-wizard-form__form-table">
        <thead>
          <tr>
            <th colSpan={2}>&nbsp;</th>
            {ratings.map((rating) => {
              const { id, label, description } = rating;

              return (
                <th key={id}>
                  <div className="ratings-header">
                    <span className="ratings-header__label">{label}</span>
                    {description && (
                      <span className="ratings-header__description">{description}</span>
                    )}
                  </div>
                </th>
              );
            })}
          </tr>
        </thead>
        <tbody>
          {answers.map((answer, index) => {
            const { id: answerId, label } = answer;
            const fieldName = `${name}.${index}.${answerId}`;
            const currentValue = watchFieldArray?.[index]?.[answerId];

            return (
              <tr key={answerId}>
                <td colSpan={2}>{label}</td>
                {ratings.map((rating) => {
                  const { id: ratingId } = rating;

                  return (
                    <td key={ratingId}>
                      <input
                        type="radio"
                        id={`${fieldName}-${ratingId}`}
                        value={ratingId}
                        checked={String(ratingId) === String(currentValue)}
                        onChange={() => setValue(fieldName, ratingId)}
                      />
                      <label htmlFor={`${fieldName}-${ratingId}`} />
                    </td>
                  );
                })}
              </tr>
            );
          })}
        </tbody>
      </table>
    </Section>
  );
};

export default Rating;
