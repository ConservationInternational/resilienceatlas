export const asyncValidate = schema => async values =>
  schema.validate(values, { abortEarly: false }).catch(errors => {
    const reduxFormErrors = errors.inner.reduce(
      (acc, error) => ({
        ...acc,
        [error.path]: error.message,
      }),
      {},
    );

    throw reduxFormErrors;
  });
