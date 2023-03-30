import api, { createApiAction } from '../../utils/api';
import { map_menu_entry } from '../../schema';

const URL_ENTRIES = '/menu-entries';

// Action constants
export const LOAD = createApiAction('map_menu_entries/LOAD');

export const load = () => api(LOAD, ({ get }) => get(URL_ENTRIES), { schema: [map_menu_entry] });
