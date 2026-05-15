import cogLayer from './cog-layer-ol';
import geeLayer from './gee-layer-ol';
import esriLayer from './esri-layer-ol';
import martinLayer from './martin-layer-ol';
import tileLayer from './tile-layer-ol';
import wmsLayer from './wms-layer-ol';
import wmtsLayer from './wmts-layer-ol';
import VectorTileLayer from 'ol/layer/VectorTile';
import { toLonLat } from 'ol/proj';

class PluginOpenLayers {
  constructor(map) {
    this.map = map;
  }

  // Stores { _clickHandler, ...originalEvents } per layerModel.id
  events = {};

  method = {
    // COG (Cloud Optimized GeoTIFF via TiTiler)
    cog: cogLayer,
    // GEE (Google Earth Engine)
    gee: geeLayer,
    // ESRI
    arcgis: esriLayer,
    featureservice: esriLayer,
    mapservice: esriLayer,
    tileservice: esriLayer,
    esrifeatureservice: esriLayer,
    esrimapservice: esriLayer,
    esritileservice: esriLayer,
    // Named WMS provider
    wms: wmsLayer,
    // Named WMTS provider
    wmts: wmtsLayer,
    // Martin PostGIS vector tiles
    martin: martinLayer,
    // xyz tileset (same as generic XYZ tile)
    'xyz tileset': tileLayer,
  };

  /**
   * Add a layer to the map.
   */
  add(layerModel) {
    const { mapLayer } = layerModel;
    if (mapLayer) this.map.addLayer(mapLayer);
  }

  /**
   * Remove a layer from the map and clean up its click handler.
   */
  remove(layerModel) {
    const { mapLayer } = layerModel;

    if (this.events[layerModel.id]?._clickHandler) {
      this.map.un('singleclick', this.events[layerModel.id]._clickHandler);
      delete this.events[layerModel.id];
    }

    if (mapLayer) {
      this.map.removeLayer(mapLayer);
    }
  }

  getLayerByProvider(provider) {
    return this.method[provider];
  }

  getLayerBoundsByProvider(provider) {
    return this.method[provider]?.getBounds;
  }

  setZIndex(layerModel, zIndex) {
    const { mapLayer } = layerModel;
    if (mapLayer) mapLayer.setZIndex(zIndex);
    return this;
  }

  setOpacity(layerModel, opacity) {
    const { mapLayer } = layerModel;
    if (mapLayer) mapLayer.setOpacity(opacity);
    return this;
  }

  /**
   * Toggle visibility by setting the layer visible flag.
   * OL's setVisible(false) properly hides the layer (no rendering).
   */
  setVisibility(layerModel, visibility) {
    const { mapLayer } = layerModel;
    if (mapLayer) mapLayer.setVisible(visibility);
    return this;
  }

  /**
   * Bind map-level click events for a layer.
   * For VectorTile layers: only fires if a feature was hit at the click pixel.
   * For raster/tile layers: fires for any map click while the layer is visible.
   */
  setEvents = (layerModel) => {
    const { mapLayer, events } = layerModel;

    // Clean up any previous click handler for this layer
    if (this.events[layerModel.id]?._clickHandler) {
      this.map.un('singleclick', this.events[layerModel.id]._clickHandler);
    }

    if (!events || !events.click) {
      this.events[layerModel.id] = events || {};
      return this;
    }

    const clickHandler = (e) => {
      if (!mapLayer?.getVisible()) return;

      // For vector tile layers: only fire if a feature was actually hit
      if (mapLayer instanceof VectorTileLayer) {
        const features = this.map.getFeaturesAtPixel(e.pixel, {
          layerFilter: (l) => l === mapLayer,
        });
        if (!features || features.length === 0) return;
      }

      const [lng, lat] = toLonLat(e.coordinate);
      events.click({ latlng: { lat, lng } });
    };

    this.map.on('singleclick', clickHandler);
    this.events[layerModel.id] = { ...events, _clickHandler: clickHandler };
    return this;
  };

  setParams(layerModel) {
    // Trigger re-render by removing the layer; LayerManager will re-add it
    this.remove(layerModel);
  }

  setLayerConfig(layerModel) {
    this.remove(layerModel);
  }

  setDecodeParams(layerModel) {
    const { mapLayer } = layerModel;
    // Force OL to re-render the layer
    if (mapLayer) mapLayer.changed();
    return this;
  }

  fitMapToLayer = (layerModel) => {
    const bounds = layerModel.get('mapLayerBounds');
    if (!bounds) return;

    // bounds is [[lat1,lng1],[lat2,lng2]] (Leaflet convention from backend)
    const [[lat1, lng1], [lat2, lng2]] = bounds;
    const extent = [
      Math.min(lng1, lng2),
      Math.min(lat1, lat2),
      Math.max(lng1, lng2),
      Math.max(lat1, lat2),
    ];

    // Transform from EPSG:4326 to map projection (EPSG:3857)
    const { transformExtent } = require('ol/proj');
    const projectedExtent = transformExtent(extent, 'EPSG:4326', 'EPSG:3857');

    this.map.getView().fit(projectedExtent, {
      padding: [50, 50, 50, 50],
      duration: 400,
      maxZoom: 16,
    });
  };
}

export default PluginOpenLayers;
