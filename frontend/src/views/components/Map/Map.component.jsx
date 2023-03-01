import React, { useCallback, useEffect, useContext } from 'react';
import qs from 'qs';
import omit from 'lodash/omit';

import { Map as Maps, MapControls, ZoomControl } from 'vizzuality-components';
import { LayerManager, Layer } from 'resilience-layer-manager/dist/components';
import { PluginLeaflet } from 'resilience-layer-manager/dist/layer-manager';

import { TABS } from '@components/Sidebar';

import { BASEMAPS } from '@views/utils';

import { LayerManagerContext } from '@contexts/layerManagerCtx';
import { setRouterParam } from '@utilities';

import Toolbar from './Toolbar';
import DrawingManager from './DrawingManager';
import MapOffset from './MapOffset';
import MapPopup from './MapPopup';

const MapView = ({
  // actions
  loadLayers,
  loadLayerGroups,
  openBatch,
  // interaction
  setMapLayerGroupsInteraction,
  setMapLayerGroupsInteractionLatLng,
  layerGroupsInteraction,
  layerGroupsInteractionSelected,
  // data
  layers: { loaded: layersLoaded },
  layer_groups: { loaded: layerGroupsLoaded },
  activeLayers,
  model_layer,
  defaultActiveGroups,
  location,
  tab,
  site,
  page,
  options,
  basemap,
  embed,
  drawing,
}) => {
  const query = qs.parse(location.search, {
    ignoreQueryPrefix: true,
    parseArrays: true,
  });

  const layerManagerRef = useContext(LayerManagerContext);

  useEffect(() => {
    if (!layersLoaded) loadLayers();
    if (!layerGroupsLoaded) loadLayerGroups();
  }, []);

  useEffect(() => {
    if (layersLoaded && layerGroupsLoaded && defaultActiveGroups.length) {
      openBatch(defaultActiveGroups);
    }
  }, [layersLoaded, layerGroupsLoaded]);

  useEffect(() => {
    const hash = activeLayers.map(({ id, opacity, chartLimit, order }) => ({
      id,
      opacity,
      order,
      chartLimit,
    }));

    if (layersLoaded) {
      setRouterParam('layers', JSON.stringify(hash));
    }
  }, [activeLayers]);

  const getCenter = useCallback(() => {
    if (query.center) {
      const decodeCenter = decodeURIComponent(query.center);
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
  }, [site.latitude, query.center]);

  return (
    <Maps
      customClass="m-map"
      basemap={{
        url: BASEMAPS[basemap].url,
      }}
      mapOptions={{
        ...options.map,
        zoom: query.zoom || site.zoom_level || 5,
        center: getCenter(),
        scrollWheelZoom: !embed,
        drawControl: true,
        minZoom: 3,
      }}
      events={{
        zoomend: (e, map) => {
          const mapZoom = map.getZoom();

          if (mapZoom !== (+site.zoom_level || 5)) {
            setRouterParam('zoom', map.getZoom());
          } else {
            // clear param if it's default
            setRouterParam('zoom');
          }

          // Update map center in url, because it basically changed
          // after 'pinches' and zoom in/out from mousewheel.
          setRouterParam('center', qs.stringify(map.getCenter()));
        },
        dragend: (e, map) => {
          setRouterParam('center', qs.stringify(map.getCenter()));
        },
      }}
    >
      {map => (
        <>
          {tab === TABS.LAYERS &&
            activeLayers.map((l, index) => (
              <LayerManager
                map={map}
                plugin={PluginLeaflet}
                ref={layerManagerRef}
                key={l.id}
              >
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
                              .output.map(o => o.column)
                              .join(',')
                          : true,
                      events: {
                        click: e => {
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
                    l.decodeParams
                      ? { ...l.decodeParams, chartLimit: l.chartLimit || 100 }
                      : null
                  }
                ></Layer>
              </LayerManager>
            ))}
          {tab === TABS.MODELS && model_layer && (
            <LayerManager
              map={map}
              plugin={PluginLeaflet}
              ref={layerManagerRef}
              key="model_layer"
            >
              <Layer key="model_layer" {...model_layer} />
            </LayerManager>
          )}

          <MapPopup map={map} />

          <DrawingManager map={map} />

          {page !== 'report' && <MapOffset map={map} />}

          {page !== 'report' && (
            <MapControls customClass="c-map-controls">
              <Toolbar />
              <ZoomControl map={map} />
            </MapControls>
          )}
        </>
      )}
    </Maps>
  );
};

export default MapView;
