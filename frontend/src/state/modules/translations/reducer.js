import { createReducer } from '../../utils';
import { SET_TRANSLATIONS } from './actions';

const initialState = {
  data: null,
};

export default createReducer(initialState)({
  [SET_TRANSLATIONS]: (state, { translations }) => ({
    ...state,
    data: translations,
  }),
});
