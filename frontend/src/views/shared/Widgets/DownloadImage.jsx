import React, { useMemo } from 'react';
import L from 'leaflet';
import { useAxios } from '@utilities';

const DownloadImage = ({ analysisBody, geojson }) => {
  const query = useMemo(() => {
    const { assetId } = JSON.parse(analysisBody);

    return {
      method: 'post',
      url:
        'https://us-central1-gef-ld-toolbox.cloudfunctions.net/download_image',
      data: {
        assetId,
        geometry: L.geoJSON(geojson).toGeoJSON(),
      },
    };
  }, [analysisBody, geojson]);
  const [url] = useAxios(query, [query]);

  if (!url) return null;

  return (
    <a
      type="button"
      className="btn-analysis btn-analysis-download"
      title="Download cropped image"
      href={url.download_url}
    >
      <svg className="icon icon-crop">
        <use xlinkHref="#icon-crop" />
      </svg>
    </a>
  );
};

export default DownloadImage;
