/**
 * ScopeGeometryLayer — Leaflet overlay for scope dataset geometries.
 *
 * Highlight mode: fetches only the single selected polygon as GeoJSON from
 * the backend and renders it with L.geoJSON — no bulk tile download.
 *
 * Spatial-filter mode: renders MVT tiles from Martin `scope_dataset_tiles`
 * to show multiple matching polygons.
 *
 * Usage: render inside the Map children function, passing the map instance:
 *   <ScopeGeometryLayer map={map} />
 */
import { useEffect, useRef, useCallback, useState } from 'react';
import { useSelector, useDispatch } from 'react-redux';

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
} from 'state/modules/scope_datasets';

const HIGHLIGHT_STYLE = {
  weight: 3,
  color: '#e74c3c',
  opacity: 1,
  fill: true,
  fillColor: '#e74c3c',
  fillOpacity: 0.3,
};

const DEFAULT_STYLE = {
  weight: 1,
  color: '#666',
  opacity: 0.6,
  fill: true,
  fillColor: '#666',
  fillOpacity: 0.05,
  interactive: true,
};

const HIDDEN_STYLE = {
  weight: 0,
  color: 'transparent',
  opacity: 0,
  fill: false,
  fillOpacity: 0,
  interactive: false,
};

function getMartinUrl() {
  const martinUrl = process.env.NEXT_PUBLIC_MARTIN_URL;
  if (!martinUrl) return null;
  return martinUrl;
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
  const highlightLayerRef = useRef(null);
  const filterLayersRef = useRef({});
  const [L, setL] = useState(null);

  // Dynamically import leaflet (requires window)
  useEffect(() => {
    import('leaflet').then((mod) => setL(mod.default || mod));
  }, []);

  // Build tile URL for a given scope_dataset_id (only used for spatial filter)
  const buildTileUrl = useCallback((datasetId) => {
    const martinUrl = getMartinUrl();
    if (!martinUrl) return null;
    return `${martinUrl}/scope_dataset_tiles/{z}/{x}/{y}?scope_dataset_id=${datasetId}`;
  }, []);

  // ── Highlight: render a single GeoJSON polygon ──
  useEffect(() => {
    if (!map || !L) return;

    // Remove previous highlight layer
    if (highlightLayerRef.current) {
      map.removeLayer(highlightLayerRef.current);
      highlightLayerRef.current = null;
    }

    // If there's no highlight or no geometry yet, nothing to render
    if (!highlight || !highlightGeometry) return;

    const layer = L.geoJSON(highlightGeometry, {
      style: () => HIGHLIGHT_STYLE,
      interactive: false,
    });
    layer.addTo(map);
    highlightLayerRef.current = layer;

    return () => {
      if (highlightLayerRef.current && map.hasLayer(highlightLayerRef.current)) {
        map.removeLayer(highlightLayerRef.current);
        highlightLayerRef.current = null;
      }
    };
  }, [map, L, highlight, highlightGeometry]);

  // ── Zoom the map to the highlighted polygon's bounding box ──
  useEffect(() => {
    if (!map || !highlightBounds || !L) return;
    try {
      const bounds = L.latLngBounds(highlightBounds);
      if (bounds.isValid()) {
        map.flyToBounds(bounds, { padding: [40, 40], maxZoom: 13, duration: 0.8 });
      }
    } catch {
      /* invalid bounds — ignore */
    }
  }, [map, highlightBounds, L]);

  // ── Spatial filter: MVT tile layers for showing multiple matching polygons ──
  useEffect(() => {
    if (!map || !loaded || !L) return;

    const VectorGrid = L.vectorGrid;
    if (!VectorGrid) {
      // VectorGrid not available — skip spatial filter rendering
      return;
    }

    // Only create tile layers when spatial filter is active (no highlight-only)
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

    // Remove layers that should no longer be shown
    Object.keys(filterLayersRef.current).forEach((slug) => {
      if (!datasetsWithGeometry.find((d) => d.slug === slug)) {
        map.removeLayer(filterLayersRef.current[slug].layer);
        delete filterLayersRef.current[slug];
      }
    });

    // Add layers for datasets that need them
    datasetsWithGeometry.forEach((dataset) => {
      if (filterLayersRef.current[dataset.slug]) return;

      const tileUrl = buildTileUrl(dataset.id);
      if (!tileUrl) return;

      const filterSet = new Set(spatialFilter[dataset.slug].map(String));

      const layer = VectorGrid.protobuf(tileUrl, {
        vectorTileLayerStyles: {
          scope_dataset_geometries: (properties) => {
            if (filterSet.has(String(properties.unit_id))) {
              return { ...DEFAULT_STYLE };
            }
            return { ...HIDDEN_STYLE };
          },
        },
        interactive: true,
        maxNativeZoom: 13,
        pane: 'overlayPane',
        getFeatureId: (f) => f.properties.unit_id,
      });

      layer.on('click', (e) => {
        const unitId = e.layer?.properties?.unit_id;
        if (unitId != null) {
          dispatch(setHighlight(dataset.slug, String(unitId)));
        }
      });

      layer.addTo(map);
      filterLayersRef.current[dataset.slug] = { layer, dataset };
    });

    return () => {
      Object.values(filterLayersRef.current).forEach(({ layer: l }) => {
        if (map.hasLayer(l)) map.removeLayer(l);
      });
      filterLayersRef.current = {};
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
    L,
  ]);

  return null;
};

export default ScopeGeometryLayer;
