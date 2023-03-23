import api, { createApiAction } from '../../utils/api';
import { journey } from '../../schema';

const URL_JOURNEYS = '/journeys';

// Action constants
export const LOAD = createApiAction('journeys/LOAD');
export const LOAD_ONE = createApiAction('journeys/LOAD_ONE');

export const load = () => api(LOAD, ({ get }) => get(URL_JOURNEYS), { schema: [journey] });

export const loadOne = (id) => api(LOAD_ONE, ({ get }) => get(`${URL_JOURNEYS}/${id}`), { id });
