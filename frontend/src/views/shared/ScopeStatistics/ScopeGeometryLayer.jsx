/**
 * ScopeGeometryLayer — OpenLayers overlay for scope dataset geometries.
 *
 * Highlight mode: fetches only the single selected polygon as GeoJSON from
 * the backend and renders it with VectorLayer — no bulk tile download.
 *
 * Spatial-filter mode: renders MVT tiles from Martin `scope_dataset_tiles`
 * to show multiple matching polygons.
 *
 * Usage: render inside the Map children function, passing the map instance:
 *   <ScopeGeometryLayer map={map} />
 */
import { useEffect, useRef, useCallback } from 'react';
import { useSelector, useDispatch } from 'react-redux';
import VectorLayer from 'ol/layer/Vector';
import VectorSource from 'ol/source/Vector';
import VectorTileLayer from 'ol/layer/VectorTile';
import VectorTileSource from 'ol/source/VectorTile';
import MVT from 'ol/format/MVT';
import GeoJSON from 'ol/format/GeoJSON';
import Style from 'ol/style/Style';
import Stroke from 'ol/style/Stroke';
import Fill from 'ol/style/Fill';
import { toLonLat } from 'ol/proj';

import {
  getLoaded,
  getDatasets,
  getHighlight,
  getHighlightBounds,
  getHighlightGeometry,
  getActiveVariant,
  getActiveDimension,
  getSpatialFilter,
  setHighlight,
  clearHighlight,
  fetchGeometryAtPoint,
} from 'state/modules/scope_datasets';

const geojsonFormat = new GeoJSON();

const HIGHLIGHT_OL_STYLE = new Style({
  stroke: new Stroke({ color: '#e74c3c', width: 3 }),
  fill: new Fill({ color: 'rgba(231,76,60,0.3)' }),
});

const DEFAULT_OL_STYLE = new Style({
  stroke: new Stroke({ color: '#666', width: 1, lineDash: [] }),
  fill: new Fill({ color: 'rgba(102,102,102,0.05)' }),
});

function getMartinUrl() {
  return process.env.NEXT_PUBLIC_MARTIN_URL || null;
}

const ScopeGeometryLayer = ({ map }) => {
  const dispatch = useDispatch();
  const loaded = useSelector(getLoaded);
  const datasets = useSelector(getDatasets);
  const highlight = useSelector(getHighlight);
  const highlightBounds = useSelector(getHighlightBounds);
  const highlightGeometry = useSelector(getHighlightGeometry);
  const activeVariant = useSelector(getActiveVariant);
  const activeDimension = useSelector(getActiveDimension);
  const spatialFilter = useSelector(getSpatialFilter);
  const analysisOpen = useSelector((state) => state.ui.analysisPanel);

  const highlightLayerRef = useRef(null);
  const skipZoomRef = useRef(false);
  const filterLayersRef = useRef({});
  const filterClickHandlersRef = useRef({});

  // Build tile URL for a given scope_dataset_id (only used for spatial filter)
  const buildTileUrl = useCallback((datasetId) => {
    const martinUrl = getMartinUrl();
    if (!martinUrl) return null;
    return `${martinUrl}/scope_dataset_tiles/{z}/{x}/{y}?scope_dataset_id=${datasetId}`;
  }, []);

  // ── Highlight: render a single GeoJSON polygon ──
  useEffect(() => {
    if (!map) return;

    // Remove previous highlight layer
    if (highlightLayerRef.current) {
      map.removeLayer(highlightLayerRef.current);
      highlightLayerRef.current = null;
    }

    if (!highlight || !highlightGeometry) return;

    const source = new VectorSource({
      features: geojsonFormat.readFeatures(highlightGeometry, {
        dataProjection: 'EPSG:4326',
        featureProjection: 'EPSG:3857',
      }),
    });

    const layer = new VectorLayer({
      source,
      style: HIGHLIGHT_OL_STYLE,
      zIndex: 1200,
      properties: { _systemLayer: true },
    });
    map.addLayer(layer);
    highlightLayerRef.current = layer;

    return () => {
      if (highlightLayerRef.current) {
        map.removeLayer(highlightLayerRef.current);
        highlightLayerRef.current = null;
      }
    };
  }, [map, highlight, highlightGeometry]);

  // ── Zoom the map to the highlighted polygon's bounding box ──
  useEffect(() => {
    if (!map || !highlightBounds) return;
    if (skipZoomRef.current) {
      skipZoomRef.current = false;
      return;
    }
    try {
      // highlightBounds is [[lat1, lng1], [lat2, lng2]]
      const [[lat1, lng1], [lat2, lng2]] = highlightBounds;
      const extent = [
        Math.min(lng1, lng2),
        Math.min(lat1, lat2),
        Math.max(lng1, lng2),
        Math.max(lat1, lat2),
      ];
      // Transform from EPSG:4326 to EPSG:3857
      const { transformExtent } = require('ol/proj');
      const projectedExtent = transformExtent(extent, 'EPSG:4326', 'EPSG:3857');
      map.getView().fit(projectedExtent, {
        padding: [40, 40, 40, 40],
        maxZoom: 13,
        duration: 400,
      });
    } catch {
      /* invalid bounds — ignore */
    }
  }, [map, highlightBounds]);

  // ── Clear highlight when analysis panel closes ──
  useEffect(() => {
    if (!analysisOpen) {
      dispatch(clearHighlight());
    }
  }, [analysisOpen, dispatch]);

  // ── Map click → point-in-polygon lookup on server (only when panel is open) ──
  useEffect(() => {
    if (!map || !loaded) return;
    if (!analysisOpen) return;

    const hasGeometries = datasets.some((d) => d.geometry_count > 0);
    if (!hasGeometries) return;

    const handleMapClick = (e) => {
      skipZoomRef.current = true;
      const [lng, lat] = toLonLat(e.coordinate);
      dispatch(fetchGeometryAtPoint(lat, lng));
    };

    map.on('singleclick', handleMapClick);
    return () => {
      map.un('singleclick', handleMapClick);
    };
  }, [map, loaded, datasets, dispatch, analysisOpen]);

  // ── Spatial filter: MVT tile layers for showing multiple matching polygons ──
  useEffect(() => {
    if (!map || !loaded) return;

    const martinUrl = getMartinUrl();
    if (!martinUrl) return;

    const datasetsWithGeometry = spatialFilter
      ? datasets.filter(
          (d) =>
            d.geometry_count &&
            d.geometry_count > 0 &&
            spatialFilter[d.slug] &&
            (!activeVariant || !d.variant_label || d.variant_label === activeVariant) &&
            (!activeDimension || !d.dimension || d.dimension === activeDimension),
        )
      : [];

    // Remove layers no longer needed
    Object.keys(filterLayersRef.current).forEach((slug) => {
      if (!datasetsWithGeometry.find((d) => d.slug === slug)) {
        map.removeLayer(filterLayersRef.current[slug].layer);
        // Clean up click handler
        if (filterClickHandlersRef.current[slug]) {
          map.un('singleclick', filterClickHandlersRef.current[slug]);
          delete filterClickHandlersRef.current[slug];
        }
        delete filterLayersRef.current[slug];
      }
    });

    // Add layers for datasets that need them
    datasetsWithGeometry.forEach((dataset) => {
      if (filterLayersRef.current[dataset.slug]) return;

      const tileUrl = buildTileUrl(dataset.id);
      if (!tileUrl) return;

      const filterSet = new Set(spatialFilter[dataset.slug].map(String));

      const source = new VectorTileSource({
        url: tileUrl,
        format: new MVT(),
        maxZoom: 13,
      });

      const layer = new VectorTileLayer({
        source,
        style: (feature) => {
          const unitId = String(feature.get('unit_id'));
          return filterSet.has(unitId) ? DEFAULT_OL_STYLE : null;
        },
        zIndex: 999,
        properties: { _systemLayer: true },
      });

      map.addLayer(layer);

      // Click handler: check if a feature in this layer was hit
      const clickHandler = (e) => {
        const features = map.getFeaturesAtPixel(e.pixel, {
          layerFilter: (l) => l === layer,
        });
        if (features && features.length > 0) {
          const unitId = features[0].get('unit_id');
          if (unitId != null) {
            dispatch(setHighlight(dataset.slug, String(unitId)));
          }
        }
      };

      map.on('singleclick', clickHandler);
      filterClickHandlersRef.current[dataset.slug] = clickHandler;
      filterLayersRef.current[dataset.slug] = { layer, dataset };
    });

    return () => {
      Object.keys(filterLayersRef.current).forEach((slug) => {
        map.removeLayer(filterLayersRef.current[slug].layer);
        if (filterClickHandlersRef.current[slug]) {
          map.un('singleclick', filterClickHandlersRef.current[slug]);
        }
      });
      filterLayersRef.current = {};
      filterClickHandlersRef.current = {};
    };
  }, [
    map,
    loaded,
    datasets,
    activeVariant,
    activeDimension,
    spatialFilter,
    buildTileUrl,
    dispatch,
  ]);

  return null;
};

export default ScopeGeometryLayer;
