import api, { createApiAction } from '../../utils/api';
import { getTableName } from './utils';
import { country } from '../../schema';

const CDB_URL = 'https://cdb-cdn.resilienceatlas.org';
const URL = '/user/ra/api/v2/sql';

export const LOAD = createApiAction('countries/LOAD');

export const load = () =>
  api(
    LOAD,
    ({ get }) => {
      const tableName = getTableName();
      const query = `SELECT name_engli as name, bbox as bbox, iso as iso, simplify_geometry as geometry FROM ${tableName}`;

      return get(URL, {
        baseURL: CDB_URL,
        params: { q: query, format: 'json' },
      });
    },
    { schema: { rows: [country] } },
  );
