import api, { createApiAction } from '../../utils/api';
import { journey } from '../../schema';

// Action constants
export const LOAD = createApiAction('journeys/LOAD');
export const LOAD_ONE = createApiAction('journeys/LOAD_ONE');

const URL_JOURNEYS = '/journeys';

const STATIC_JOURNEYS = process.env.NEXT_PUBLIC_STATIC_JOURNEYS === 'true';

export const load = () =>
  STATIC_JOURNEYS
    ? api(LOAD, ({ get }) => get('/static-journeys/journeysPageIndex.json', { baseURL: '/' }), {
        schema: [journey],
      })
    : api(LOAD, ({ get }) => get(URL_JOURNEYS), { schema: [journey] });

export const loadOne = (id) =>
  STATIC_JOURNEYS
    ? api(LOAD_ONE, ({ get }) => get(`/static-journeys/${id}.json`, { baseURL: '/' }), { id })
    : api(LOAD_ONE, ({ get }) => get(`${URL_JOURNEYS}/${id}`), { id });
