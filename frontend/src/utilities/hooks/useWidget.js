import cx from 'classnames';
import { useMemo, useCallback } from 'react';
import { useAxios } from './useAxios';

const sqlApi = 'https://cdb-cdn.resilienceatlas.org/user/ra/api/v2/sql';

export const useWidget = ({ slug, geojson }, { type, analysisQuery, analysisBody }) => {
  const isCOGLayer = useMemo(() => type === 'cog', [type]);
  const query = useMemo(() => {
    if (analysisBody) {
      const { assetId, params } = JSON.parse(analysisBody);
      let parsedQuery = analysisQuery;

      if (isCOGLayer && params && typeof params === 'object') {
        Object.entries(params).forEach(([key, value]) => {
          parsedQuery = parsedQuery.replace(`{{${key}}}`, value);
        });
      }

      return {
        method: 'post',
        url: parsedQuery,
        data: {
          assetId,
          ...(isCOGLayer
            ? { ...L.geoJSON(geojson).toGeoJSON() }
            : { geometry: L.geoJSON(geojson).toGeoJSON() }),
        },
      };
    }

    const geometry = geojson.features ? geojson.features[0].geometry : geojson.geometry || geojson;

    const q = analysisQuery.replace(/{{geometry}}/g, JSON.stringify(geometry));

    return {
      method: 'get',
      url: sqlApi,
      params: {
        q,
      },
    };
  }, [analysisBody, geojson, analysisQuery, isCOGLayer]);

  const [data, loading, loaded] = useAxios(query, [query]);

  const rootWidgetProps = useCallback(
    () => ({
      id: `widget-${slug.replace(' ', '-')}`,
      className: cx('m-widget', {
        'is-loading': loading,
        loaded,
      }),
    }),
    [loading, loaded, slug],
  );

  const noData =
    !data ||
    (isCOGLayer ? !data.features || !data.features.length : !data.rows || !data.rows.length);

  let parsedData = data;
  if (isCOGLayer) {
    const statistics = data?.features?.[0]?.properties?.statistics;
    const firstColumn = statistics && Object.values(statistics)?.[0];
    const { histogram } = firstColumn || {};
    const rows = histogram?.[0].map((count, i) => ({
      mappingValue: histogram[1][i],
      count,
    }));
    parsedData = { rows, stats: firstColumn };
  }
  return {
    rootWidgetProps,
    loaded,
    loading,
    data: parsedData,
    noData,
  };
};
