import React, { useMemo } from 'react';
import { geoJSON } from 'leaflet';
import { useAxios } from 'utilities';
import { T } from '@transifex/react';

const DownloadImage = ({ analysisBody, geojson }) => {
  const query = useMemo(() => {
    const { assetId } = JSON.parse(analysisBody);

    return {
      method: 'post',
      url: 'https://downloadimage.tt.resilienceatlas.org',
      data: {
        assetId,
        geometry: geoJSON(geojson).toGeoJSON(),
      },
    };
  }, [analysisBody, geojson]);
  const [url] = useAxios(query, [query]);

  if (!url) return null;

  return (
    <a
      type="button"
      className="btn-analysis btn-analysis-download"
      title={<T _str="Download cropped image" />}
      href={url.download_url}
    >
      <svg className="icon icon-crop">
        <use xlinkHref="#icon-crop" />
      </svg>
    </a>
  );
};

export default DownloadImage;
