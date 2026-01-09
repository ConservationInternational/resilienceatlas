import { createReducer } from '../../utils';
import { LOAD } from './actions';
import { SectionTypes } from 'types/about';

const initialState = {
  data: {
    intro: null,
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
    const getSections = () => {
      const allItems = payload.included;
      if (!allItems.length) return null;
      const staticPageSections = payload.included.filter((s) => s.type === SectionTypes.section);
      return staticPageSections.map((s) => {
        const sectionWithContent = { ...s.attributes };
        const sectionParagraph = s.relationships.section_paragraph.data;
        const sectionItems = s.relationships.section_items.data;
        const sectionReferences = s.relationships.section_references.data;

        if (sectionParagraph) {
          sectionWithContent.paragraph = allItems.find(
            (i) => i.type === SectionTypes.paragraphs && i.id === sectionParagraph.id,
          )?.attributes;
        }
        if (sectionItems?.length) {
          const itemIds = sectionItems.map((item) => item.id);
          sectionWithContent.items = allItems
            .filter((i) => i.type === SectionTypes.items && itemIds.includes(i.id))
            .map((i) => ({ ...i.attributes }));
        }
        if (sectionReferences?.length) {
          const referenceIds = sectionReferences.map((reference) => reference.id);
          sectionWithContent.references = allItems
            .filter((i) => i.type === SectionTypes.references && referenceIds.includes(i.id))
            .map((i) => ({ ...i.attributes }));
        }
        return sectionWithContent;
      });
    };

    return {
      ...state,
      data: { intro: payload?.data?.attributes || {}, sections: getSections() },
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
