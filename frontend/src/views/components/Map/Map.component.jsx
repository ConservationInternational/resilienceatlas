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

import { BASEMAPS } from 'views/utils';

import { LayerManagerContext } from 'views/contexts/layerManagerCtx';
import { useRouterParams } from 'utilities';

import Toolbar from './Toolbar';
import DrawingManager from './DrawingManager';
import MapOffset from './MapOffset';
import MapPopup from './MapPopup';

const MapView = (props) => {
  const {
    // actions
    loadLayers,
    loadLayerGroups,
    openBatch,
    // interaction
    setMapLayerGroupsInteraction,
    setMapLayerGroupsInteractionLatLng,
    // data
    layers: { loaded: layersLoaded, loadedLocale: layersLoadedLocale },
    layer_groups: { loaded: layerGroupsLoaded, loadedLocale: layerGroupsLoadedLocale },
    activeLayers,
    model_layer,
    defaultActiveGroups,
    router,
    tab,
    site,
    page,
    options,
    basemap,
    embed,
    drawing,
  } = props;
  const { query, locale } = router;
  const { setParam } = useRouterParams();

  const layerManagerRef = useContext(LayerManagerContext);

  useEffect(() => {
    if (!layersLoaded || layersLoadedLocale !== locale) loadLayers(locale);
    if (!layerGroupsLoaded || layerGroupsLoadedLocale !== locale) loadLayerGroups(locale);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [locale]);

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
    // eslint-disable-next-line react-hooks/exhaustive-deps
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
