import { useEffect, useCallback } from 'react';
import qs from 'qs';

export const useLoadLayers = ({
  layersLoadedSubdomain,
  subdomain,
  layerGroupsLoadedSubdomain,
  layersLoaded,
  layersLoadedLocale,
  locale,
  loadLayers,
  loadLayerGroups,
  layerGroupsLoaded,
  layerGroupsLoadedLocale,
}: {
  layersLoadedSubdomain: string;
  subdomain: string;
  layerGroupsLoadedSubdomain: string;
  layersLoaded: boolean;
  layersLoadedLocale: string;
  locale: string;
  loadLayers: (locale: string) => void;
  loadLayerGroups: (locale: string) => void;
  layerGroupsLoaded: boolean;
  layerGroupsLoadedLocale: string;
}) => {
  const subdomainIsDifferentThanLoaded =
    layersLoadedSubdomain !== subdomain && (layersLoadedSubdomain || subdomain);
  const layerGroupsSubdomainIsDifferentThanLoaded =
    layerGroupsLoadedSubdomain !== subdomain && (layerGroupsLoadedSubdomain || subdomain);

  useEffect(() => {
    if (!layersLoaded || layersLoadedLocale !== locale || subdomainIsDifferentThanLoaded) {
      loadLayers(locale);
    }

    if (
      !layerGroupsLoaded ||
      layerGroupsLoadedLocale !== locale ||
      layerGroupsSubdomainIsDifferentThanLoaded
    ) {
      loadLayerGroups(locale);
    }
  }, [
    layerGroupsLoaded,
    layerGroupsLoadedLocale,
    layerGroupsSubdomainIsDifferentThanLoaded,
    layersLoaded,
    layersLoadedLocale,
    loadLayerGroups,
    loadLayers,
    locale,
    subdomainIsDifferentThanLoaded,
  ]);
};

export const useGetCenter = ({
  site,
  query,
}: {
  site?: {
    latitude: number;
    longitude: number;
  };
  query: {
    center?: string;
  };
}) =>
  useCallback(() => {
    const DEFAULT_CENTER = { lat: 3.86, lng: 47.28 };
    if (query.center) {
      const decodeCenter = decodeURIComponent(query.center as string);
      if (decodeCenter && decodeCenter[0] === '{') {
        try {
          return JSON.parse(decodeCenter);
        } catch (error) {
          // eslint-disable-next-line no-console
          console.error('Error parsing center', decodeCenter, error);
          return DEFAULT_CENTER;
        }
      }
      const center = qs.parse(query.center);
      return center;
    }

    // Safely access site properties with optional chaining
    if (site?.latitude) {
      return { lat: site.latitude, lng: site.longitude };
    }

    return DEFAULT_CENTER;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [site?.latitude, query.center]);
