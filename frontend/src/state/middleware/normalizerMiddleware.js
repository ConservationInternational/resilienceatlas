import { normalizer } from 'normalizr';
import { createUnion } from '../utils/detectSchema';

const normalizerMiddleware = () => (next) => (action) => {
  const { payload, error, meta: { schema, ...restMeta } = {} } = action;
  let { includedSchema } = action.meta || {};

  if (schema && payload && !error) {
    const { data, included: includedData = [], meta } = payload;
    const normalized = normalizer(data, schema);
    let included;

    if (includedSchema) {
      if (includedSchema === 'union') {
        includedSchema = createUnion(includedData);
      }
      included = normalizer(includedData, includedSchema);
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

export default normalizerMiddleware;
