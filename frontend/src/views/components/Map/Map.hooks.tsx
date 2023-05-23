import { useMemo, useEffect, useCallback } from 'react';
import { replace } from 'resilience-layer-manager';
import { timeParse } from 'd3-time-format';
import qs from 'qs';

export const useUpdateDateInLayers = (activeLayers) =>
  useMemo(() => {
    const getDateParams = (timeline, date) => {
      const parseDate = timeParse(timeline.format);
      const selectedDate = date ? parseDate(date) : timeline.defaultDate;
      return {
        day: selectedDate.getDate(),
        month: selectedDate.getMonth(),
        year: selectedDate.getFullYear(),
      };
    };

    return activeLayers.map((layer) => {
      const { layerConfig, timeline, date } = layer || {};
      if (!timeline) {
        return layer;
      }
      // Only for COG layers?
      const parsedLayer = {
        ...layer,
        layerConfig: {
          ...layerConfig,
          body: {
            ...layerConfig.body,
            url:
              layerConfig?.body?.url &&
              replace(layerConfig?.body?.url, getDateParams(timeline, date)),
          },
        },
      };
      return parsedLayer;
    });
  }, [activeLayers]);

export const useLoadLayers = (
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
) => {
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

export const useGetCenter = (site, query) =>
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

    if (site.latitude) {
      return { lat: site.latitude, lng: site.longitude };
    }

    return DEFAULT_CENTER;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [site.latitude, query.center]);
