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

  // Boolean: whether any interaction (highlight or spatial filter) is active.
  // Used as a stable dependency so that switching between highlighted rows
  // does NOT destroy / recreate tile layers (which would trigger new fetches).
  const hasInteraction = !!(highlight || spatialFilter);

  // Create / destroy vector tile layers.
  // Depends on the stable boolean `hasInteraction`, NOT on the highlight
  // object itself.  Switching rows keeps hasInteraction === true, so layers
  // stay on the map and only their styles are updated (see next effect).
  useEffect(() => {
    if (!map || !loaded || !L) return;

    const VectorGrid = L.vectorGrid;
    if (!VectorGrid) return;

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

    // Cleanup on unmount or when interaction stops / datasets change
    return () => {
      Object.values(layersRef.current).forEach(({ layer: l }) => {
        if (map.hasLayer(l)) map.removeLayer(l);
      });
      layersRef.current = {};
    };
  }, [map, loaded, datasets, activeVariant, activeDimension, hasInteraction, buildTileUrl, dispatch, L]);

  // Update feature styles when highlight or spatial filter changes.
  // Uses setFeatureStyle/resetFeatureStyle to restyle already-rendered
  // features in-place, avoiding the tile re-fetch that redraw() causes.
  useEffect(() => {
    Object.entries(layersRef.current).forEach(([slug, { layer }]) => {
      if (!layer.options?.vectorTileLayerStyles) return;

      // Build set of matching unit IDs for this dataset from the spatial filter
      const filterSet =
        spatialFilter && spatialFilter[slug] ? new Set(spatialFilter[slug].map(String)) : null;

      // Compute the style function — used for tiles that load AFTER this update
      let styleFn;

      if (!highlight && !filterSet) {
        styleFn = () => ({ ...DEFAULT_STYLE });
      } else if (highlight && highlight.datasetSlug === slug) {
        styleFn = (properties) => {
          if (String(properties.unit_id) === highlight.unitId) {
            return { ...HIGHLIGHT_STYLE };
          }
          return { ...DIMMED_STYLE };
        };
      } else if (highlight) {
        styleFn = () => ({ ...DIMMED_STYLE });
      } else if (filterSet) {
        styleFn = (properties) => {
          if (filterSet.has(String(properties.unit_id))) {
            return { ...DEFAULT_STYLE };
          }
          return { ...DIMMED_STYLE };
        };
      }

      if (styleFn) {
        // Update style function for future tiles
        layer.options.vectorTileLayerStyles.scope_dataset_geometries = styleFn;

        // Restyle already-rendered features in-place (no tile re-fetch).
        // VectorGrid stores rendered features in _vectorTiles.
        const tiles = layer._vectorTiles;
        if (tiles) {
          Object.values(tiles).forEach((tile) => {
            const features = tile._features?.scope_dataset_geometries;
            if (!features) return;
            Object.entries(features).forEach(([id, featureInfo]) => {
              const props = featureInfo?.feature?.properties || {};
              const style = styleFn(props);
              try {
                layer.setFeatureStyle(id, style);
              } catch (_) {
                /* feature may not support setFeatureStyle */
              }
            });
          });
        }
      }
    });
  }, [highlight, spatialFilter]);

  return null;
};

export default ScopeGeometryLayer;
