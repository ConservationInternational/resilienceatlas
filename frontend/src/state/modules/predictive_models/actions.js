import api, { createApiAction } from '../../utils/api';
import { model } from '../../schema';

const URL_MODELS = '/models';

// Action constants
export const LOAD = createApiAction('models/LOAD');

export const SELECT = 'models / SELECT';
export const TOGGLE_INDICATOR = 'models / TOGGLE_INDICATOR';
export const UDPATE_INDICATOR = 'models / UPDATE_INDICATOR';
export const RESET_INDICATORS = 'models / RESET_INDICATORS';
export const APPLY_INDICATORS = 'models / APPLY_INDICATORS';

// Actions
export const select = (id) => ({
  type: SELECT,
  id,
});

export const toggleIndicator = (index) => ({
  type: TOGGLE_INDICATOR,
  index,
});

export const updateIndicator = (index, indexableValue) => ({
  type: UDPATE_INDICATOR,
  index,
  indexableValue,
});

export const applyIndicators = () => ({
  type: APPLY_INDICATORS,
});

export const resetIndicators = () => ({
  type: RESET_INDICATORS,
});

export const load = () =>
  api(
    LOAD,
    ({ get }, d, getState) => {
      const site_scope = getState().site.id;

      return get(URL_MODELS, { params: { site_scope } });
    },
    {
      schema: [model],
      includedSchema: 'union',
    },
  );
