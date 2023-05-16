import React, { useEffect, useMemo } from 'react';
import { Field, FieldArray } from 'redux-form';
import { t } from '@transifex/native';
import { useRouter } from 'next/router';
import Section from 'views/components/WizardForm/Section';

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

const RatingItem = (props) => {
  const { input } = props;
  const { locale } = useRouter();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  const ratings = useMemo(() => getRatings(), [locale]);
  return ratings.map((rating, index) => {
    const { id } = rating;

    return (
      <>
        <td key={index}>
          <input
            type="radio"
            {...input}
            id={`${input.name}-${id}`}
            value={id}
            checked={id == input.value}
          />
          <label htmlFor={`${input.name}-${id}`} />
        </td>
      </>
    );
  });
};

const RatingGroup = (props) => {
  const { fields, answers } = props;
  const { name: fieldName } = fields;

  useEffect(() => {
    if (fields.length >= answers.length) return;

    answers.forEach(({ id }) => {
      fields.push({ [id]: null });
    });

    // TODO Simao: Add comment
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <>
      {answers.map((answer, index) => {
        const { id: name, label } = answer;
        return (
          <tr key={name}>
            <td colSpan={2}>{label}</td>
            <Field component={RatingItem} name={`${fieldName}[${index}].${name}`} answer={props} />
          </tr>
        );
      })}
    </>
  );
};

const Rating = (props) => {
  const { id: name, answers } = props;
  const { locale } = useRouter();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  const ratings = useMemo(() => getRatings(), [locale]);
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
          <FieldArray component={RatingGroup} name={name} answers={answers} />
        </tbody>
      </table>
    </Section>
  );
};

export default Rating;
