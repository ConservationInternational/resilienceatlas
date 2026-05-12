import React, { useMemo } from 'react';
import L from 'leaflet';
import { useQuery } from '@tanstack/react-query';
import axios from 'axios';
import { T } from '@transifex/react';

const DownloadImage = ({ analysisBody, geojson }) => {
  const query = useMemo(() => {
    const { assetId } = JSON.parse(analysisBody);

    return {
      method: 'post',
      url: 'https://downloadimage.tt.resilienceatlas.org',
      data: {
        assetId,
        geometry: L.geoJSON(geojson).toGeoJSON(),
      },
    };
  }, [analysisBody, geojson]);
  const { data: url } = useQuery({
    queryKey: ['download-image', query],
    queryFn: ({ signal }) => axios({ ...query, signal }).then((res) => res.data),
    staleTime: 30 * 60 * 1000,
    gcTime: 60 * 60 * 1000,
    retry: 1,
  });

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
