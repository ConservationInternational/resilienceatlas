import { createReducer } from '../../utils';
import { LOAD } from './actions';
import { SectionTypes } from 'types/homepage';

const initialState = {
  homepage: {
    intro: null,
    journeys: null,
    sections: null,
  },
  loading: false,
  loaded: false,
  loadedLocale: null,
  error: null,
};

export default createReducer(initialState)({
  [LOAD.REQUEST]: (state) => ({
    ...state,
    loading: true,
    error: null,
  }),

  [LOAD.SUCCESS]: (state, { payload, meta: { locale } }) => {
    const getSectionsForType = (type) =>
      (payload.included || [])
        .filter((included) => included.type === type)
        .map((included) => ({ id: included.id, ...included.attributes }));

    return {
      ...state,
      intro: payload?.data?.attributes || {},
      journeys: getSectionsForType(SectionTypes.Journey),
      sections: getSectionsForType(SectionTypes.Section),
      loading: false,
      loaded: true,
      loadedLocale: locale,
    };
  },

  [LOAD.FAIL]: (state, { error }) => ({
    ...state,
    loading: false,
    error,
  }),
});
