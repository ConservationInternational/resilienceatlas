import { replace } from '../../utils/query';
import VectorTileLayer from 'ol/layer/VectorTile';
import VectorTileSource from 'ol/source/VectorTile';
import MVT from 'ol/format/MVT';
import { buildVectorTileStyle, pathOptionsToStyle } from './style-converter';

/**
 * Build an OL StyleFunction from a colorRamp config stored in layer_config.body.
 *
 * colorRamp shape:
 *   property: string    — MVT feature property holding the numeric value
 *   breaks:   number[]  — n-1 break thresholds defining n colour bins
 *   colors:   string[]  — n hex colours (one per bin, first for lowest values)
 *   default:  string    — fill colour for null / out-of-range features
 */
function buildColorRampStyle(colorRamp) {
  const { property, breaks, colors, default: defaultColor = '#aaaaaa' } = colorRamp;

  return (feature) => {
    const val = feature.get(property);
    let color = defaultColor;

    if (val !== null && val !== undefined) {
      let bin = colors.length - 1; // last bin (highest values)
      for (let i = 0; i < breaks.length; i++) {
        if (val < breaks[i]) {
          bin = i;
          break;
        }
      }
      color = colors[bin];
    }

    return pathOptionsToStyle({
      fillColor: color,
      fillOpacity: 0.8,
      color: '#ffffff',
      weight: 0.3,
      opacity: 0.5,
    });
  };
}

/**
 * Martin PostGIS vector tile layer handler for OpenLayers.
 *
 * Expects layerConfig.body:
 *   source: Martin source name (PostGIS table or function), e.g. "my_table"
 *   styles: VectorGrid-compatible styles object keyed by MVT layer name
 *   options: Optional extra layer options (maxNativeZoom, etc.)
 *   mapboxStyle: Optional Mapbox GL style JSON (used instead of styles when present)
 */
const MartinLayerOL = (layerModel) => {
  const martinUrl = process.env.NEXT_PUBLIC_MARTIN_URL;
  if (!martinUrl) throw new Error('NEXT_PUBLIC_MARTIN_URL is not configured.');

  const { layerConfig, params, sqlParams } = layerModel;
  const layerConfigParsed =
    layerConfig.parse === false
      ? layerConfig
      : JSON.parse(replace(JSON.stringify(layerConfig), params, sqlParams));

  return new Promise((resolve) => {
    const { body } = layerConfigParsed;
    const { source, styles, colorRamp, options = {} } = body;

    const tileUrl = `${martinUrl}/${source}/{z}/{x}/{y}`;

    const vectorTileSource = new VectorTileSource({
      url: tileUrl,
      format: new MVT(),
      maxZoom: options.maxNativeZoom ?? 14,
    });

    let styleFunction;
    if (colorRamp) {
      styleFunction = buildColorRampStyle(colorRamp);
    } else if (styles) {
      styleFunction = buildVectorTileStyle(styles);
    }

    const layer = new VectorTileLayer({
      source: vectorTileSource,
      style: styleFunction,
      opacity: layerModel.opacity ?? 1,
      zIndex: layerModel.zIndex,
      properties: { _provider: 'martin', _layerId: layerModel.id, _isVectorTile: true },
    });

    resolve(layer);
  });
};

MartinLayerOL.getBounds = () => Promise.resolve(null);

export default MartinLayerOL;
