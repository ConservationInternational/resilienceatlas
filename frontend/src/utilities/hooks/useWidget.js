import cx from 'classnames';
import { useMemo, useCallback } from 'react';
import { useAxios } from './useAxios';

const sqlApi = 'https://cdb-cdn.resilienceatlas.org/user/ra/api/v2/sql';

export const useWidget = ({ slug, geojson }, { analysisQuery, analysisBody }) => {
  const query = useMemo(() => {
    if (analysisBody) {
      const { assetId } = JSON.parse(analysisBody);

      return {
        method: 'post',
        url: analysisQuery,
        data: {
          assetId,
          geometry: L.geoJSON(geojson).toGeoJSON(),
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
  }, [geojson, analysisQuery, analysisBody]);

  const [data, loading, loaded] = useAxios(query, [query]);

  const rootWidgetProps = useCallback(
    () => ({
      id: `widget-${slug}`,
      className: cx('m-widget', {
        'is-loading': loading,
        loaded,
      }),
    }),
    [loading],
  );

  const noData = !data || !data.rows || !data.rows.length;

  return {
    rootWidgetProps,
    loaded,
    loading,
    data,
    noData,
  };
};
