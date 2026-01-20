// Import leaflet and make it globally available BEFORE importing plugins
import L from 'leaflet';

// These will be dynamically imported on client-side only
let LayerManager: typeof import('lib/layer-manager/components').LayerManager;
let Layer: typeof import('lib/layer-manager/components').Layer;
let PluginLeaflet: typeof import('lib/layer-manager/plugins/plugin-leaflet').default;

// Make L globally available for plugins that expect it (like leaflet-geoman)
// This must happen before importing plugins, so we use a side-effect approach
if (typeof window !== 'undefined') {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  (window as any).L = L;

  // Now import plugins that depend on window.L
  // Using require() to ensure they run after the window.L assignment above
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  require('@geoman-io/leaflet-geoman-free');
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  require('leaflet-active-area');
  // UTFGrid library requires corslite, only included in the minimized version
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  require('leaflet-utfgrid/L.UTFGrid-min');

  // Import layer-manager components that also require window.L
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const components = require('lib/layer-manager/components');
  LayerManager = components.LayerManager;
  Layer = components.Layer;
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const lm = require('lib/layer-manager/plugins/plugin-leaflet');
  PluginLeaflet = lm.default;
}

// CSS imports must be static for bundler to process them
import '@geoman-io/leaflet-geoman-free/dist/leaflet-geoman.css';

import { useRouterParams } from 'utilities';
import React, { useCallback, useEffect, useContext, useMemo, useState } from 'react';
import qs from 'qs';
import omit from 'lodash/omit';
import pick from 'lodash/pick';
import type { MapViewProps } from './types';
import { LeafletMap, MapControls, ZoomControl } from './LeafletMap/exports';
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
import LayerErrorModal, { type LayerError } from 'views/components/LayerErrorModal';
import CompareControl from './CompareControl';

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
    // Compare mode - simplified props
    compareEnabled,
    compareURLState,
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

  // Update URL with compare state - uses selector-computed state to avoid duplication
  useEffect(() => {
    if (compareURLState) {
      setParam('compare', JSON.stringify(compareURLState));
    } else {
      setParam('compare', null);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [compareURLState]);

  const getCenter = useGetCenter({ site, query });

  // Layer error handling
  const [layerErrors, setLayerErrors] = useState<LayerError[]>([]);

  const onLayerError = useCallback((error: LayerError) => {
    // Skip bounds errors - they are non-critical since the layer can still render
    // without bounds data. Bounds are only used for "zoom to fit" functionality.
    if (error.errorType === 'bounds') {
      console.warn(
        `Layer bounds failed to load for ${error.layerName}, but layer will still render.`,
      );
      return;
    }

    setLayerErrors((prev) => {
      // Avoid duplicate errors for the same layer
      if (prev.some((e) => e.layerId === error.layerId)) {
        return prev;
      }
      return [...prev, error];
    });
  }, []);

  const handleCloseErrorModal = useCallback(() => {
    setLayerErrors([]);
  }, []);

  const handleDismissError = useCallback((layerId: string | number) => {
    setLayerErrors((prev) => prev.filter((e) => e.layerId !== layerId));
  }, []);

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

  // Memoize label and basemap configs to prevent infinite re-renders
  const safeLabel = useMemo(() => {
    const labelConfig = LABELS[labels];
    return labelConfig?.url ? { url: labelConfig.url, options: {} } : undefined;
  }, [labels]);

  const safeBasemap = useMemo(() => {
    const basemapConfig = BASEMAPS[basemap];
    return basemapConfig ? { url: basemapConfig.url, options: {} } : undefined;
  }, [basemap]);

  // Build map container classes
  const mapClasses = useMemo(() => {
    const classes = ['m-map'];
    if (compareEnabled) {
      classes.push('compare-mode');
    }
    return classes.join(' ');
  }, [compareEnabled]);

  return (
    <LeafletMap
      customClass={mapClasses}
      label={safeLabel}
      basemap={safeBasemap}
      mapOptions={{
        ...(options?.map || {}),
        zoom: Number(query.zoom) || site?.zoom_level || 2,
        center: getCenter(),
        scrollWheelZoom: !embed,
        drawControl: true,
        minZoom: 3,
        maxZoom: 13,
      }}
      events={{
        layeradd: (e) => {
          const layer = (e as L.LayerEvent).layer as L.TileLayer;
          if (
            // to avoid displaying loading state with labels
            (layer as { _url?: string })?._url?.startsWith(
              'https://api.mapbox.com/styles/v1/cigrp',
            ) ||
            // to avoid displaying loading state when the user interacts with the map (click on a layer)
            Object.prototype.hasOwnProperty.call(layer, '_content')
          )
            return;
          onLayerLoading(true);
          layer.on('load', onLayerLoaded);
        },
        zoomend: (e, map) => {
          const mapZoom = map.getZoom();

          if (mapZoom !== (+site?.zoom_level || 2)) {
            setParam('zoom', String(map.getZoom()));
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
          {tab === TABS.LAYERS && activeLayers && activeLayers.length > 0 && (
            <LayerManager
              map={map}
              plugin={PluginLeaflet}
              ref={layerManagerRef}
              onLayerLoading={onLayerLoading}
              onLayerError={onLayerError}
            >
              {activeLayers.map((l, index) => (
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
                />
              ))}
            </LayerManager>
          )}

          {tab === TABS.MODELS && model_layer && (
            <LayerManager
              map={map}
              plugin={PluginLeaflet}
              ref={layerManagerRef}
              key="model_layer"
              onLayerError={onLayerError}
            >
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

          {/* Compare mode control */}
          {compareEnabled && <CompareControl map={map} />}

          <LayerErrorModal
            errors={layerErrors}
            onClose={handleCloseErrorModal}
            onDismissError={handleDismissError}
          />
        </>
      )}
    </LeafletMap>
  );
};

export default MapView;
