/**
 * ScopeGeometryLayer — Leaflet vector tile overlay for scope dataset geometries.
 *
 * Renders MVT tiles from the Martin `scope_dataset_tiles` function source.
 * Supports bidirectional highlighting: Redux state drives visual highlight,
 * and clicks on polygons dispatch highlight actions back to Redux.
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
  getActiveVariant,
  getActiveDimension,
  getSpatialFilter,
  setHighlight,
} from 'state/modules/scope_datasets';

const DEFAULT_STYLE = {
  weight: 1,
  color: '#666',
  opacity: 0.6,
  fill: true,
  fillColor: '#666',
  fillOpacity: 0.05,
  interactive: true,
};

const HIGHLIGHT_STYLE = {
  weight: 3,
  color: '#e74c3c',
  opacity: 1,
  fill: true,
  fillColor: '#e74c3c',
  fillOpacity: 0.3,
};

const DIMMED_STYLE = {
  weight: 0.5,
  color: '#999',
  opacity: 0.3,
  fill: true,
  fillColor: '#999',
  fillOpacity: 0.02,
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
  const activeVariant = useSelector(getActiveVariant);
  const activeDimension = useSelector(getActiveDimension);
  const spatialFilter = useSelector(getSpatialFilter);
  const layersRef = useRef({});
  const [L, setL] = useState(null);

  // Dynamically import leaflet (requires window)
  useEffect(() => {
    import('leaflet').then((mod) => setL(mod.default || mod));
  }, []);

  // Build tile URL for a given scope_dataset_id
  const buildTileUrl = useCallback((datasetId) => {
    const martinUrl = getMartinUrl();
    if (!martinUrl) return null;
    return `${martinUrl}/scope_dataset_tiles/{z}/{x}/{y}?scope_dataset_id=${datasetId}`;
  }, []);

  // Add/remove vector tile layers on demand — only when a row is
  // highlighted or a spatial filter (search) is active.
  useEffect(() => {
    if (!map || !loaded || !L) return;

    const VectorGrid = L.vectorGrid;
    if (!VectorGrid) return;

    const hasInteraction = !!(highlight || spatialFilter);

    // Determine which datasets should have geometry layers right now
    const datasetsWithGeometry = hasInteraction
      ? datasets.filter(
          (d) =>
            d.geometry_count &&
            d.geometry_count > 0 &&
            (!activeVariant || !d.variant_label || d.variant_label === activeVariant) &&
            (!activeDimension || !d.dimension || d.dimension === activeDimension),
        )
      : [];

    // Remove layers that should no longer be shown
    Object.keys(layersRef.current).forEach((slug) => {
      if (!datasetsWithGeometry.find((d) => d.slug === slug)) {
        map.removeLayer(layersRef.current[slug].layer);
        delete layersRef.current[slug];
      }
    });

    // Add layers for datasets that need them
    datasetsWithGeometry.forEach((dataset) => {
      if (layersRef.current[dataset.slug]) return;

      const tileUrl = buildTileUrl(dataset.id);
      if (!tileUrl) return;

      const layer = VectorGrid.protobuf(tileUrl, {
        vectorTileLayerStyles: {
          scope_dataset_geometries: () => ({ ...DEFAULT_STYLE }),
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
      layersRef.current[dataset.slug] = { layer, dataset };
    });

    // Cleanup on unmount
    return () => {
      Object.values(layersRef.current).forEach(({ layer: l }) => {
        if (map.hasLayer(l)) map.removeLayer(l);
      });
      layersRef.current = {};
    };
  }, [map, loaded, datasets, activeVariant, activeDimension, highlight, spatialFilter, buildTileUrl, dispatch, L]);

  // Update feature styles when highlight or spatial filter changes
  useEffect(() => {
    Object.entries(layersRef.current).forEach(([slug, { layer }]) => {
      if (!layer.options?.vectorTileLayerStyles) return;

      // Build set of matching unit IDs for this dataset from the spatial filter
      const filterSet =
        spatialFilter && spatialFilter[slug] ? new Set(spatialFilter[slug].map(String)) : null;

      let styleFn;

      if (!highlight && !filterSet) {
        // No highlight and no spatial filter — reset all to default
        styleFn = () => ({ ...DEFAULT_STYLE });
      } else if (highlight && highlight.datasetSlug === slug) {
        // This dataset has the highlighted unit — highlight matched, dim rest
        styleFn = (properties) => {
          if (String(properties.unit_id) === highlight.unitId) {
            return { ...HIGHLIGHT_STYLE };
          }
          return { ...DIMMED_STYLE };
        };
      } else if (highlight) {
        // Other dataset — dim everything during highlight
        styleFn = () => ({ ...DIMMED_STYLE });
      } else if (filterSet) {
        // Spatial filter active, no highlight — show matching, dim non-matching
        styleFn = (properties) => {
          if (filterSet.has(String(properties.unit_id))) {
            return { ...DEFAULT_STYLE };
          }
          return { ...DIMMED_STYLE };
        };
      }

      if (styleFn) {
        layer.options.vectorTileLayerStyles.scope_dataset_geometries = styleFn;
        layer.redraw();
      }
    });
  }, [highlight, spatialFilter]);

  return null;
};

export default ScopeGeometryLayer;
