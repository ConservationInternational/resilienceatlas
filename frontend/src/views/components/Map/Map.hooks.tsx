import { useEffect, useCallback, useRef } from 'react';
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
  // Track which locale/subdomain we've already loaded for
  const loadedLayersForRef = useRef<string | null>(null);
  const loadedLayerGroupsForRef = useRef<string | null>(null);

  useEffect(() => {
    const layersKey = `${locale}-${subdomain}`;
    const layerGroupsKey = `${locale}-${subdomain}`;

    // Only load layers if we haven't loaded for this locale/subdomain combination
    // or if the loaded data is for a different locale/subdomain
    const needsLayersLoad =
      !layersLoaded ||
      layersLoadedLocale !== locale ||
      (layersLoadedSubdomain !== subdomain && (layersLoadedSubdomain || subdomain));

    const needsLayerGroupsLoad =
      !layerGroupsLoaded ||
      layerGroupsLoadedLocale !== locale ||
      (layerGroupsLoadedSubdomain !== subdomain && (layerGroupsLoadedSubdomain || subdomain));

    if (needsLayersLoad && loadedLayersForRef.current !== layersKey) {
      loadedLayersForRef.current = layersKey;
      loadLayers(locale);
    }

    if (needsLayerGroupsLoad && loadedLayerGroupsForRef.current !== layerGroupsKey) {
      loadedLayerGroupsForRef.current = layerGroupsKey;
      loadLayerGroups(locale);
    }
  }, [
    layerGroupsLoaded,
    layerGroupsLoadedLocale,
    layerGroupsLoadedSubdomain,
    layersLoaded,
    layersLoadedLocale,
    layersLoadedSubdomain,
    loadLayerGroups,
    loadLayers,
    locale,
    subdomain,
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
