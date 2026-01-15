import isEmpty from 'lodash/isEmpty';

import LayerModel from './layer-model';

function checkPluginProperties(plugin) {
  if (plugin) {
    const requiredProperties = [
      'add',
      'remove',
      'setVisibility',
      'setOpacity',
      'setEvents',
      'setZIndex',
      'setLayerConfig',
      'setParams',
      'setDecodeParams',
      'getLayerByProvider',
    ];

    requiredProperties.forEach((property) => {
      if (!plugin[property]) {
        console.error(`The ${property} function is required for layer manager plugins`);
      }
    });
  }
}

class LayerManager {
  constructor(map, Plugin, options = {}) {
    this.map = map;
    this.plugin = new Plugin(this.map);
    checkPluginProperties(this.plugin);
    this.layers = [];
    this.promises = {};
    this.pendingRequests = {}; // Track layers with in-flight requests
    this.failedLayers = {}; // Track layers that failed to load (to prevent infinite retries)
    this.onLayerError = options.onLayerError || null; // Callback for layer errors
  }

  /**
   * Render layers
   */
  renderLayers() {
    if (this.layers.length > 0) {
      this.layers.forEach((layerModel) => {
        const { changedAttributes } = layerModel;
        const { sqlParams, params, layerConfig } = changedAttributes;
        const hasChanged = Object.keys(changedAttributes).length > 0;
        const shouldUpdate = sqlParams || params || layerConfig;

        // If layer already exists on map and nothing changed, skip entirely
        if (layerModel.mapLayer && !hasChanged) {
          return;
        }

        // If layer exists and only non-critical attributes changed, just update
        if (layerModel.mapLayer && hasChanged && !shouldUpdate) {
          this.updateLayer(layerModel);
          layerModel.set('changedAttributes', {});
          return;
        }

        // If layer exists and needs full update (params/config changed)
        if (layerModel.mapLayer && shouldUpdate) {
          this.updateLayer(layerModel);
        }

        // Only request new layer if it doesn't exist on map yet, no request is pending, and it hasn't failed
        if (
          !layerModel.mapLayer &&
          !this.pendingRequests[layerModel.id] &&
          !this.failedLayers[layerModel.id]
        ) {
          this.requestLayer(layerModel);
          this.requestLayerBounds(layerModel);
        }

        // reset changedAttributes
        layerModel.set('changedAttributes', {});
      });

      if (Object.keys(this.promises).length === 0) {
        return Promise.resolve(this.layers);
      }

      return Promise.all(Object.values(this.promises))
        .then(() => this.layers)
        .then(() => {
          this.promises = {};
        })
        .catch((error) => {
          // Catch any remaining unhandled errors to prevent them from bubbling up
          console.error('[LayerManager] Error in renderLayers:', error);
          this.promises = {};
          return this.layers;
        });
    }

    // By default it will return a empty layers
    return Promise.resolve(this.layers);
  }

  /**
   * Add layers
   * @param {Array} layers
   * @param {Object} layerOptions
   */
  add(
    layers,
    layerOptions = {
      opacity: 1,
      visibility: true,
      zIndex: 0,
      interactivity: null,
    },
  ) {
    if (typeof layers === 'undefined') {
      console.error('layers is required');
      return this;
    }

    if (!Array.isArray(layers)) {
      console.error('layers should be an array');
      return this;
    }

    layers.forEach((layer) => {
      const existingLayer = this.layers.find((l) => l.id === layer.id);
      const nextModel = { ...layer, ...layerOptions };

      if (existingLayer) {
        existingLayer.update(nextModel);
      } else {
        this.layers.push(new LayerModel(nextModel));
      }
    });

    return this.layers;
  }

  /**
   * Updating a specific layer
   * @param  {Object} layerModel
   */
  updateLayer(layerModel) {
    const { opacity, visibility, zIndex, params, sqlParams, decodeParams, layerConfig, events } =
      layerModel.changedAttributes;

    if (typeof opacity !== 'undefined') {
      this.plugin.setOpacity(layerModel, opacity);
    }
    if (typeof visibility !== 'undefined') {
      this.plugin.setOpacity(layerModel, !visibility ? 0 : layerModel.opacity);
    }
    if (typeof zIndex !== 'undefined') {
      this.plugin.setZIndex(layerModel, zIndex);
    }
    if (typeof events !== 'undefined') {
      this.setEvents(layerModel);
    }

    if (!isEmpty(layerConfig)) this.plugin.setLayerConfig(layerModel);
    if (!isEmpty(params)) this.plugin.setParams(layerModel);
    if (!isEmpty(sqlParams)) this.plugin.setParams(layerModel);
    if (!isEmpty(decodeParams)) this.plugin.setDecodeParams(layerModel);
  }

  /**
   * Remove a layer giving a Layer ID
   * @param {Array} layerIds
   */
  remove(layerIds) {
    const layers = this.layers.slice(0);
    const ids = Array.isArray(layerIds) ? layerIds : [layerIds];

    this.layers.forEach((layerModel, index) => {
      if (ids) {
        if (ids.includes(layerModel.id)) {
          this.plugin.remove(layerModel);
          layers.splice(index, 1);
        }
      } else {
        this.plugin.remove(layerModel);
      }
    });

    this.layers = ids ? layers : [];
  }

  /**
   * A namespace to set opacity on selected layer
   * @param {Array} layerIds
   * @param {Number} opacity
   */
  setOpacity(layerIds, opacity) {
    const layerModels = this.layers.filter((l) => layerIds.includes(l.id));

    if (layerModels.length) {
      layerModels.forEach((lm) => {
        this.plugin.setOpacity(lm, opacity);
      });
    } else {
      console.error("Can't find the layer");
    }
  }

  /**
   * A namespace to hide or show a selected layer
   * @param {Array} layerIds
   * @param {Boolean} visibility
   */
  setVisibility(layerIds, visibility) {
    const layerModels = this.layers.filter((l) => layerIds.includes(l.id));

    if (layerModels.length) {
      layerModels.forEach((lm) => {
        this.plugin.setVisibility(lm, visibility);
      });
    } else {
      console.error("Can't find the layer");
    }
  }

  /**
   * A namespace to set z-index on selected layer
   * @param {Array} layerIds
   * @param {Number} zIndex
   */
  setZIndex(layerIds, zIndex) {
    const layerModels = this.layers.filter((l) => layerIds.includes(l.id));

    if (layerModels.length) {
      layerModels.forEach((lm) => {
        this.plugin.setZIndex(lm, zIndex);
      });
    } else {
      console.error("Can't find the layer");
    }
  }

  /**
   * A namespace to set events on selected layer
   * @param  {Object} layerModel
   */
  setEvents(layerModel) {
    const { events } = layerModel;

    if (events) {
      // Let's leave the managment of event to the plugin
      this.plugin.setEvents(layerModel);
    }
  }

  fitMapToLayer(layerId) {
    if (typeof this.plugin.fitMapToLayer !== 'function') {
      console.error('This plugin does not support fitting map bounds to layer yet.');
      return;
    }

    const layerModel = this.layers.find((l) => l.id === layerId);

    if (layerModel) this.plugin.fitMapToLayer(layerModel);
  }

  requestLayer(layerModel) {
    const { provider } = layerModel;
    const method = this.plugin.getLayerByProvider(provider);

    if (!method) {
      const error = new Error(`${provider} provider is not yet supported.`);
      console.error(`Error loading layer ${layerModel.id}:`, error);
      this.failedLayers[layerModel.id] = { error, timestamp: Date.now() };
      layerModel.set('loadError', error);

      // Call error callback if provided
      if (this.onLayerError) {
        this.onLayerError({
          layerId: layerModel.id,
          layerName: layerModel.name || layerModel.id,
          error,
          timestamp: Date.now(),
        });
      }
      return false;
    }

    // Mark this layer as having a pending request
    this.pendingRequests[layerModel.id] = true;

    // every render method returns a promise that we store in the array
    // to control when all layers are fetched.
    this.promises[layerModel.id] = method
      .call(this, layerModel)
      .then((layer) => {
        const mapLayer = layer;

        layerModel.set('mapLayer', mapLayer);

        // Clear pending flag
        delete this.pendingRequests[layerModel.id];

        this.requestLayerSuccess(layerModel);

        this.setEvents(layerModel);
      })
      .catch((error) => {
        // Clear pending flag on error
        delete this.pendingRequests[layerModel.id];
        // Mark layer as failed to prevent infinite retries
        this.failedLayers[layerModel.id] = { error, timestamp: Date.now() };
        layerModel.set('loadError', error);
        console.error(`Error loading layer ${layerModel.id}:`, error);

        // Call error callback if provided
        if (this.onLayerError) {
          this.onLayerError({
            layerId: layerModel.id,
            layerName: layerModel.name || layerModel.id,
            errorType: 'layer',
            errorDescription: 'Failed to load layer data',
            provider: layerModel.provider,
            url: error.config?.url || null,
            error,
            timestamp: Date.now(),
          });
        }
      });

    return this;
  }

  requestLayerSuccess(layerModel) {
    this.plugin.add(layerModel);
    this.plugin.setZIndex(layerModel, layerModel.zIndex);
    this.plugin.setOpacity(layerModel, layerModel.opacity);
    this.plugin.setVisibility(layerModel, layerModel.visibility);
  }

  requestLayerBounds(layerModel) {
    const { provider } = layerModel;
    const method = this.plugin.getLayerBoundsByProvider(provider);

    if (!method) {
      return false;
    }

    const promiseHash = `${layerModel.id}_bounds`;

    // Skip if already pending
    if (this.pendingRequests[promiseHash]) {
      return false;
    }

    this.pendingRequests[promiseHash] = true;

    // every render method returns a promise that we store in the array
    // to control when all layers are fetched.
    this.promises[promiseHash] = method
      .call(this, layerModel)
      .then((bounds) => {
        delete this.pendingRequests[promiseHash];
        layerModel.set('mapLayerBounds', bounds);
      })
      .catch((error) => {
        delete this.pendingRequests[promiseHash];
        // Mark bounds request as failed to prevent infinite retries
        this.failedLayers[promiseHash] = { error, timestamp: Date.now() };
        // Use console.warn instead of console.error since bounds errors are non-critical
        // The layer will still render without bounds data (bounds are only used for "zoom to fit")
        console.warn(`Bounds request failed for layer ${layerModel.id} (${layerModel.name || 'unnamed'}), but layer will still render.`);

        // Call error callback if provided (bounds errors are less critical, include context)
        if (this.onLayerError) {
          this.onLayerError({
            layerId: layerModel.id,
            layerName: layerModel.name || layerModel.id,
            errorType: 'bounds',
            errorDescription: 'Failed to load layer boundaries',
            provider: layerModel.provider,
            url: error.config?.url || null,
            error,
            timestamp: Date.now(),
          });
        }
      });

    return this;
  }
}

export default LayerManager;
