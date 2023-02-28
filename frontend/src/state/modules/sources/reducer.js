import { createReducer } from '../../utils';
import { LOAD as LAYERS_LOAD } from '../layers';

const initialState = {
  byId: {
    /* [layerId]: { layer } */
  },
  all: [
    /* layerId */
  ],
  loading: false,
  loaded: false,
  error: null,
};

export default createReducer(initialState)({
  [LAYERS_LOAD.SUCCESS]: (state, { included }) => ({
    ...state,
    byId: included.entities.sources,
  }),
});
