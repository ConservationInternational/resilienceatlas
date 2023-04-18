import api, { createApiAction } from '../../utils/api';
import { map_menu_entry } from '../../schema';
import { toBackendLocale } from 'utilities';

const URL_ENTRIES = '/menu-entries';

// Action constants
export const LOAD = createApiAction('map_menu_entries/LOAD');

export const load = (locale) =>
  api(LOAD, ({ get }) => get(URL_ENTRIES, { params: { locale: toBackendLocale(locale) } }), {
    schema: [map_menu_entry],
  });
