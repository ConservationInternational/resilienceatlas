import 'leaflet';
import 'leaflet.pm';
import 'leaflet-active-area';
// UTFGrid library requires corslite, only included in the minimized version
import 'leaflet-utfgrid/L.UTFGrid-min';

import React, { useCallback, useEffect, useContext } from 'react';
import qs from 'qs';
import omit from 'lodash/omit';

import { Map as Maps, MapControls, ZoomControl } from 'vizzuality-components';
import { LayerManager, Layer } from 'resilience-layer-manager/dist/components';
import { PluginLeaflet } from 'resilience-layer-manager/dist/layer-manager';

import { TABS } from 'views/components/Sidebar';

import { BASEMAPS, LABELS } from 'views/utils';

import { LayerManagerContext } from 'views/contexts/layerManagerCtx';
import { useRouterParams } from 'utilities';
import { subdomain } from 'utilities/getSubdomain';
import type { MAP_LABELS, BASEMAP_LABELS } from 'views/components/LayersList/Basemaps/constants';
import type { NextRouter } from 'next/router';

import Toolbar from './Toolbar';
import DrawingManager from './DrawingManager';
import MapOffset from './MapOffset';
import MapPopup from './MapPopup';

interface MapViewProps {
  labels: (typeof MAP_LABELS)[number];
  basemap: (typeof BASEMAP_LABELS)[number];
  router: NextRouter;
  onLoadingLayers?: (loaded: boolean) => void;
  [k: string]: unknown;
}

const MapView = (props: MapViewProps) => {
  const {
    // actions
    loadLayers,
    loadLayerGroups,
    openBatch,
    // interaction
    setMapLayerGroupsInteraction,
    setMapLayerGroupsInteractionLatLng,
    // data
    layers: {
      loaded: layersLoaded,
      loadedLocale: layersLoadedLocale,
      loadedSubdomain: layersLoadedSubdomain,
    },
    layer_groups: {
      loaded: layerGroupsLoaded,
      loadedLocale: layerGroupsLoadedLocale,
      loadedSubdomain: layerGroupsLoadedSubdomain,
    },
    activeLayers,
    model_layer,
    defaultActiveGroups,
    router,
    tab,
    site,
    page,
    options,
    basemap,
    labels,
    embed,
    drawing,
    onLoadingLayers,
  } = props;
  const { query, locale } = router;
  const { setParam } = useRouterParams();
  const layerManagerRef = useContext(LayerManagerContext);
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

  useEffect(() => {
    if (layersLoaded && layerGroupsLoaded && defaultActiveGroups.length) {
      openBatch(defaultActiveGroups);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [layersLoaded, layerGroupsLoaded]);

  useEffect(() => {
    const hash = activeLayers.map(({ id, opacity, chartLimit, order }) => ({
      id,
      opacity,
      order,
      chartLimit,
    }));

    if (layersLoaded) {
      setParam('layers', JSON.stringify(hash));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeLayers]);

  const getCenter = useCallback(() => {
    if (query.center) {
      const decodeCenter = decodeURIComponent(query.center as string);
      if (decodeCenter && decodeCenter[0] === '{') {
        return JSON.parse(decodeCenter);
      }
      const center = qs.parse(query.center);
      return center;
    }

    if (site.latitude) {
      return { lat: site.latitude, lng: site.longitude };
    }

    return { lat: 3.86, lng: 47.28 };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [site.latitude, query.center]);

  const onLayerLoading = useCallback(
    (_isAnyLayerLoading: boolean) => {
      onLoadingLayers?.(_isAnyLayerLoading);
    },
    [onLoadingLayers],
  );

  const onLayerLoaded = useCallback(() => {
    onLayerLoading(false);
  }, [onLayerLoading]);

  return (
    <Maps
      customClass="m-map"
      label={LABELS[labels]}
      basemap={BASEMAPS[basemap]}
      mapOptions={{
        ...options.map,
        zoom: query.zoom || site.zoom_level || 5,
        center: getCenter(),
        scrollWheelZoom: !embed,
        drawControl: true,
        minZoom: 3,
        maxZoom: 13,
      }}
      events={{
        layeradd: ({ layer }) => {
          if (
            // to avoid displaying loading state with labels
            layer?._url?.startsWith('https://api.mapbox.com/styles/v1/cigrp') ||
            // to avoid displaying loading state when the user interacts with the map (click on a layer)
            layer.hasOwnProperty('_content')
          )
            return null;
          onLayerLoading(true);
          return layer.on('load', onLayerLoaded);
        },
        zoomend: (e, map) => {
          const mapZoom = map.getZoom();

          if (mapZoom !== (+site.zoom_level || 5)) {
            setParam('zoom', map.getZoom());
          } else {
            // clear param if it's default
            setParam('zoom');
          }

          // Update map center in url, because it basically changed
          // after 'pinches' and zoom in/out from mousewheel.
          setParam('center', qs.stringify(map.getCenter()));
        },
        dragend: (e, map) => {
          setParam('center', qs.stringify(map.getCenter()));
        },
      }}
    >
      {(map) => (
        <>
          {tab === TABS.LAYERS &&
            activeLayers.map((l) => (
              <LayerManager map={map} plugin={PluginLeaflet} ref={layerManagerRef} key={l.id}>
                <Layer
                  {...omit(l, 'interactivity')}
                  slug={l.slug || l.id}
                  key={l.id}
                  // Interaction
                  {...(!!l.interactionConfig &&
                    !!l.interactionConfig &&
                    !!l.interactionConfig.length && {
                      interactivity:
                        l.provider === 'carto' || l.provider === 'cartodb'
                          ? JSON.parse(l.interactionConfig)
                              .output.map((o) => o.column)
                              .join(',')
                          : true,
                      events: {
                        click: (e) => {
                          if (!drawing) {
                            setMapLayerGroupsInteraction({
                              ...e,
                              ...l,
                            });

                            setMapLayerGroupsInteractionLatLng(e.latlng);
                          }
                        },
                      },
                    })}
                  decodeParams={
                    l.decodeParams ? { ...l.decodeParams, chartLimit: l.chartLimit || 100 } : null
                  }
                ></Layer>
              </LayerManager>
            ))}

          {tab === TABS.MODELS && model_layer && (
            <LayerManager map={map} plugin={PluginLeaflet} ref={layerManagerRef} key="model_layer">
              <Layer key="model_layer" {...model_layer} />
            </LayerManager>
          )}

          <MapPopup map={map} />

          <DrawingManager map={map} />

          {page !== 'report' && <MapOffset map={map} />}

          {page !== 'report' && (
            <MapControls customClass="c-map-controls">
              <ZoomControl map={map} />
              <Toolbar />
            </MapControls>
          )}
        </>
      )}
    </Maps>
  );
};

export default MapView;
