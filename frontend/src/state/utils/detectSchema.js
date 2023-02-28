import { schema } from 'normalizr';
import * as schemas from '../schema';

export const detectSchema = name => {
  const detectedSchema = Object.values(schemas).find(sc => sc.key === name);

  if (!detectedSchema) return null;

  return detectedSchema;
};

export const createUnion = data => {
  const unionObj = data.reduce((acc, val) => {
    const detectedSchema = detectSchema(val.type);

    if (!detectedSchema) return acc;

    return {
      ...acc,
      [val.type]: detectedSchema,
    };
  }, {});

  return [new schema.Union(unionObj, 'type')];
};
