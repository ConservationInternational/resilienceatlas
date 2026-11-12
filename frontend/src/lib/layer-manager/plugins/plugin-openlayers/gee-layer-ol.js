import { replace } from '../../utils/query';
import TileLayer from 'ol/layer/Tile';
import XYZ from 'ol/source/XYZ';
import { scopeDataUrl } from 'utilities/scopeDataUrl';
import { getApiBaseUrl } from '../../../../utilities/environment';

/**
 * GEE (Google Earth Engine) tile layer handler for OpenLayers.
 *
 * The API supplies a scope-authenticated gateway URL, not an Earth Engine token.
 *
 * Layers with a decodeFunction (e.g. SPARC visualizer layers) use a custom
 * tileLoadFunction that applies canvas-based pixel decoding to every tile.
 * A mutable `_decodeRef` is stored on the layer so that setDecodeParams can
 * update the params and call source.refresh() without recreating the layer.
 */
const GEELayerOL = (layerModel) => {
  const { layerConfig, params, sqlParams, decodeFunction, decodeParams } = layerModel;
  const layerConfigParsed =
    layerConfig.parse === false
      ? layerConfig
      : JSON.parse(replace(JSON.stringify(layerConfig), params, sqlParams));

  return new Promise((resolve) => {
    const { body } = layerConfigParsed;
    const { url, options = {} } = body;
    const publicTileUrl = body.public_tile_url
      ? body.public_tile_url.startsWith('https://')
        ? body.public_tile_url
        : `${getApiBaseUrl().replace(/\/$/, '')}${body.public_tile_url}`
      : null;

    if (!publicTileUrl && !url) {
      console.error('[GEE Layer OL] No tile URL in layerConfig.body.url');
      resolve(null);
      return;
    }

    // Mutable ref shared with the plugin so setDecodeParams can update params
    // and trigger a source refresh without recreating the whole layer.
    const decodeRef = { params: decodeParams || {}, fn: decodeFunction || null };

    const tileLoadFunction = decodeRef.fn
      ? (tile, src) => {
          const image = tile.getImage();
          const img = new Image();
          img.crossOrigin = 'anonymous';
          img.onload = () => {
            const canvas = document.createElement('canvas');
            canvas.width = img.naturalWidth || 256;
            canvas.height = img.naturalHeight || 256;
            const ctx = canvas.getContext('2d');
            ctx.drawImage(img, 0, 0);
            const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
            decodeRef.fn(imageData.data, canvas.width, canvas.height, 0, decodeRef.params);
            ctx.putImageData(imageData, 0, 0);
            image.src = canvas.toDataURL();
          };
          img.onerror = () => {
            // Fallback: let OL display the raw tile on fetch error
            image.src = src;
          };
          img.src = src;
        }
      : undefined;

    const sourceOptions = {
      url: publicTileUrl || scopeDataUrl(url),
      crossOrigin: 'anonymous',
      tileSize: options.tileSize || 256,
    };
    if (tileLoadFunction) {
      sourceOptions.tileLoadFunction = tileLoadFunction;
    }

    const layer = new TileLayer({
      source: new XYZ(sourceOptions),
      opacity: layerModel.opacity ?? 1,
      zIndex: layerModel.zIndex,
      properties: {
        _provider: 'gee',
        _layerId: layerModel.id,
        _decodeRef: decodeRef,
      },
    });

    resolve(layer);
  });
};

GEELayerOL.getBounds = () => Promise.resolve(null);

export default GEELayerOL;
