// These will be dynamically imported on client-side only
// eslint-disable-next-line @typescript-eslint/consistent-type-imports
let LayerManager: typeof import('lib/layer-manager/components').LayerManager;
// eslint-disable-next-line @typescript-eslint/consistent-type-imports
let Layer: typeof import('lib/layer-manager/components').Layer;
// eslint-disable-next-line @typescript-eslint/consistent-type-imports
let PluginOpenLayers: typeof import('lib/layer-manager/plugins/plugin-openlayers').default;

if (typeof window !== 'undefined') {
  // Import layer-manager components
  const components = require('lib/layer-manager/components');
  LayerManager = components.LayerManager;
  Layer = components.Layer;
  const lm = require('lib/layer-manager/plugins/plugin-openlayers');
  PluginOpenLayers = lm.default;
}

import { useRouterParams } from 'utilities';
import React, { useCallback, useEffect, useContext, useMemo } from 'react';
import { useState } from 'react';
import qs from 'qs';
import { toLonLat } from 'ol/proj';
import type OlMap from 'ol/Map';
import omit from 'lodash/omit';
import pick from 'lodash/pick';
import type { MapViewProps } from './types';
import { OLMap, MapControls, ZoomControl } from './OLMap/exports';
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
import { ScopeGeometryLayer } from 'views/shared/ScopeStatistics';

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
    boundaries,
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
      // eslint-disable-next-line no-console
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
    <OLMap
      customClass={mapClasses}
      label={safeLabel}
      basemap={safeBasemap}
      boundaries={boundaries}
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
        zoomend: (map: OlMap) => {
          const view = map.getView();
          const mapZoom = Math.round(view.getZoom() ?? 2);

          if (mapZoom !== (+site?.zoom_level || 2)) {
            setParam('zoom', String(mapZoom));
          } else {
            // clear param if it's default
            setParam('zoom', null);
          }

          // Update map center in url, because it basically changed
          // after 'pinches' and zoom in/out from mousewheel.
          const [lng, lat] = toLonLat(view.getCenter() ?? [0, 20]);
          setParam('center', qs.stringify({ lat, lng }));
        },
        dragend: (map: OlMap) => {
          const view = map.getView();
          const [lng, lat] = toLonLat(view.getCenter() ?? [0, 20]);
          setParam('center', qs.stringify({ lat, lng }));
        },
      }}
    >
      {(map) => (
        <>
          {tab === TABS.LAYERS && activeLayers && activeLayers.length > 0 && (
            <LayerManager
              map={map}
              plugin={PluginOpenLayers}
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
              plugin={PluginOpenLayers}
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

          {/* Scope dataset geometry overlay for chart↔map interaction */}
          <ScopeGeometryLayer map={map} />

          <LayerErrorModal
            errors={layerErrors}
            onClose={handleCloseErrorModal}
            onDismissError={handleDismissError}
          />
        </>
      )}
    </OLMap>
  );
};

export default MapView;
