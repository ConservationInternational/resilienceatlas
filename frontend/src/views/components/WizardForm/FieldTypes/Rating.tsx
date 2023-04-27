import React, { useEffect } from 'react';
import { Field, FieldArray } from 'redux-form';

const RATINGS = [
  {
    id: 1,
    label: '1',
    description: 'Strongly Disagree',
  },
  {
    id: 2,
    label: '2',
  },
  {
    id: 3,
    label: '3',
  },
  {
    id: 4,
    label: '4',
  },
  {
    id: 5,
    label: '5',
    description: 'Strongly Agree',
  },
];

const RatingItem = (props) => {
  const { input } = props;

  return RATINGS.map((rating, index) => {
    const { id } = rating;

    return (
      <>
        <td key={index}>
          <input type="radio" {...input} value={id} checked={id == input.value} />
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
            <td>{label}</td>
            <Field component={RatingItem} name={`${fieldName}[${index}].${name}`} answer={props} />
          </tr>
        );
      })}
    </>
  );
};

const Rating = (props) => {
  const { id: name, answers } = props;

  return (
    <table className="m-wizard-form__form-table">
      <thead>
        <tr>
          <th>&nbsp;</th>
          {RATINGS.map((rating) => {
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
  );
};

export default Rating;
