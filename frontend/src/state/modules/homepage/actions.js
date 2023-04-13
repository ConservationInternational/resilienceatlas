import api, { createApiAction } from '../../utils/api';

const URL_HOMEPAGE = '/homepage';

export const LOAD = createApiAction('homepage/LOAD');

export const load = () => api(LOAD, ({ get }) => get(URL_HOMEPAGE));
