import api, { createApiAction } from '../../utils/api';
import { journey } from '../../schema';

// Action constants
export const LOAD = createApiAction('journeys/LOAD');
export const LOAD_ONE = createApiAction('journeys/LOAD_ONE');

export const load = () =>
  api(LOAD, ({ get }) => get('/static-journeys/journeysPageIndex.json', { baseURL: '/' }), {
    schema: [journey],
  });

export const loadOne = (id) =>
  api(LOAD_ONE, ({ get }) => get(`/static-journeys/${id}.json`, { baseURL: '/' }), { id });

// Recover these two fuctions when the backend is ready for journeys

// const URL_JOURNEYS = '/journeys';
// export const load = () => api(LOAD, ({ get }) => get(URL_JOURNEYS), { schema: [journey] });
// export const loadOne = (id) => api(LOAD_ONE, ({ get }) => get(`${URL_JOURNEYS}/${id}`), { id });
