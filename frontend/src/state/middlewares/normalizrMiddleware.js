import { normalize } from 'normalizr';
import { createUnion } from '../utils/detectSchema';

export default store => next => action => {
  const { payload, error, meta: { schema, ...restMeta } = {} } = action;
  let { includedSchema } = action.meta || {};

  if (schema && payload && !error) {
    const { data, included: includedData = [], meta } = payload;
    const normalized = normalize(data, schema);
    let included;

    if (includedSchema) {
      if (includedSchema === 'union') {
        includedSchema = createUnion(includedData);
      }
      included = normalize(includedData, includedSchema);
    }

    action = {
      ...action,
      payload: normalized,
      included,
      meta: { ...meta, ...restMeta },
    };
  }

  return next(action);
};
