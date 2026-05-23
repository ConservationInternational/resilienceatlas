import cogLayer from './cog-layer-ol';
import geeLayer from './gee-layer-ol';
import esriLayer from './esri-layer-ol';
import martinLayer from './martin-layer-ol';
import tileLayer from './tile-layer-ol';
import wmsLayer from './wms-layer-ol';
import wmtsLayer from './wmts-layer-ol';
import VectorTileLayer from 'ol/layer/VectorTile';
import { toLonLat, transformExtent } from 'ol/proj';

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

      // For vector tile layers: only fire if a feature was actually hit,
      // and pass its properties directly so the popup doesn't need an HTTP call.
      if (mapLayer instanceof VectorTileLayer) {
        const features = this.map.getFeaturesAtPixel(e.pixel, {
          layerFilter: (l) => l === mapLayer,
        });
        if (!features || features.length === 0) return;

        const [lng, lat] = toLonLat(e.coordinate);
        // Strip the OL internal geometry key from the properties object
        const { geometry: _geom, ...data } = features[0]?.getProperties() || {};
        events.click({ latlng: { lat, lng }, data: Object.keys(data).length ? data : undefined });
        return;
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
    const { mapLayer, decodeParams } = layerModel;
    if (!mapLayer) return this;

    // For layers with a canvas decode function (e.g. GEE/SPARC), update the
    // mutable decodeRef and refresh the tile source so every tile is
    // re-fetched and re-decoded with the new params (e.g. updated chartLimit).
    const decodeRef = mapLayer.get('_decodeRef');
    if (decodeRef) {
      decodeRef.params = decodeParams || {};
      const source = typeof mapLayer.getSource === 'function' ? mapLayer.getSource() : null;
      if (source && typeof source.refresh === 'function') {
        source.refresh();
      } else {
        mapLayer.changed();
      }
    } else {
      mapLayer.changed();
    }

    return this;
  }

  fitMapToLayer = async (layerModel) => {
    let bounds = layerModel.get('mapLayerBounds');

    // If bounds weren't cached on load, try to fetch them now
    if (!bounds) {
      const getBoundsMethod = this.getLayerBoundsByProvider(layerModel.provider);
      if (!getBoundsMethod) return;
      try {
        bounds = await getBoundsMethod.call(this, layerModel);
      } catch {
        return;
      }
      if (!bounds) return;
      layerModel.set('mapLayerBounds', bounds);
    }

    // bounds is [[lat1,lng1],[lat2,lng2]] (Leaflet convention: [[south,west],[north,east]])
    const [[lat1, lng1], [lat2, lng2]] = bounds;

    // Clamp latitudes to valid Web Mercator range — EPSG:3857 can't represent ±90°
    // and transformExtent would produce ±Infinity → NaN map center.
    const MAX_LAT = 85.051129;
    const clampLat = (lat) => Math.max(-MAX_LAT, Math.min(MAX_LAT, lat));

    const extent = [
      Math.min(lng1, lng2),
      clampLat(Math.min(lat1, lat2)),
      Math.max(lng1, lng2),
      clampLat(Math.max(lat1, lat2)),
    ];

    const projectedExtent = transformExtent(extent, 'EPSG:4326', 'EPSG:3857');

    this.map.getView().fit(projectedExtent, {
      padding: [50, 50, 50, 50],
      duration: 400,
      maxZoom: 16,
    });
  };
}

export default PluginOpenLayers;
