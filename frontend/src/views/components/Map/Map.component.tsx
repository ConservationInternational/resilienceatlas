import 'leaflet';
import '@geoman-io/leaflet-geoman-free';
import '@geoman-io/leaflet-geoman-free/dist/leaflet-geoman.css';
import 'leaflet-active-area';
// UTFGrid library requires corslite, only included in the minimized version
import 'leaflet-utfgrid/L.UTFGrid-min';
import { useRouterParams } from 'utilities';
import React, { useCallback, useEffect, useContext } from 'react';
import qs from 'qs';
import omit from 'lodash/omit';
import pick from 'lodash/pick';
import type { MapViewProps } from './types';
import { Map as Maps, MapControls, ZoomControl } from 'vizzuality-components';
import { LayerManager, Layer } from 'resilience-layer-manager/dist/components';
import { PluginLeaflet } from 'resilience-layer-manager/dist/layer-manager';
import { TABS } from 'views/components/Sidebar';
import { useLoadLayers, useGetCenter } from './Map.hooks';
import { BASEMAPS, LABELS } from 'views/utils';
import { URL_PERSISTED_KEYS } from 'state/modules/layers/utils';

import { LayerManagerContext } from 'views/contexts/layerManagerCtx';
import { subdomain } from 'utilities/getSubdomain';
import Toolbar from './Toolbar';
import DrawingManager from './DrawingManager';
import MapOffset from './MapOffset';
import MapPopup from './MapPopup';

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

  useLoadLayers({
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
  });

  // Open default active layer groups
  useEffect(() => {
    if (layersLoaded && layerGroupsLoaded && defaultActiveGroups.length) {
      openBatch(defaultActiveGroups);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [layersLoaded, layerGroupsLoaded]);

  // Update URL with active layers
  useEffect(() => {
    const hash = (activeLayers || []).map((activeLayer) =>
      pick(activeLayer, ['id', ...URL_PERSISTED_KEYS]),
    );
    if (layersLoaded) {
      setParam('layers', JSON.stringify(hash));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeLayers]);

  const getCenter = useGetCenter({ site, query });

  const onLayerLoading = useCallback(
    (_isAnyLayerLoading: boolean) => {
      onLoadingLayers?.(_isAnyLayerLoading);
    },
    [onLoadingLayers],
  );

  const onLayerLoaded = useCallback(() => {
    onLayerLoading(false);
  }, [onLayerLoading]);

  const MAX_LAYER_Z_INDEX = 1000;

  return (
    <Maps
      customClass="m-map"
      label={LABELS[labels]}
      basemap={BASEMAPS[basemap]}
      mapOptions={{
        ...(options?.map || {}),
        zoom: query.zoom || site?.zoom_level || 5,
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
            Object.prototype.hasOwnProperty.call(layer, '_content')
          )
            return null;
          onLayerLoading(true);
          layer.on('load', onLayerLoaded);
          return undefined;
        },
        zoomend: (e, map) => {
          const mapZoom = map.getZoom();

          if (mapZoom !== (+site?.zoom_level || 5)) {
            setParam('zoom', map.getZoom());
          } else {
            // clear param if it's default
            setParam('zoom', null);
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
            activeLayers?.map((l, index) => (
              <LayerManager map={map} plugin={PluginLeaflet} ref={layerManagerRef} key={l.id}>
                <Layer
                  {...omit(l, 'interactivity')}
                  slug={l.slug || l.id}
                  key={l.id}
                  zIndex={MAX_LAYER_Z_INDEX - index}
                  // Interaction
                  {...(!!l.interactionConfig &&
                    !!l.interactionConfig &&
                    !!l.interactionConfig.length && {
                      interactivity:
                        l.provider === 'carto' || l.provider === 'cartodb' || l.provider === 'cog'
                          ? (JSON.parse(l.interactionConfig)?.output || [])
                              .map((o) => o.column)
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
