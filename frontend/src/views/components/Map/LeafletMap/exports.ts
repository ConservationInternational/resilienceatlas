/**
 * Native Leaflet components for React 19
 * Replaces vizzuality-components Map, MapControls, ZoomControl, and MapPopup
 */

export { default as LeafletMap } from './index';
export type {
  LeafletMapProps,
  LeafletMapRef,
  MapOptions,
  BasemapConfig,
  LabelConfig,
  MapEvents,
} from './index';

export { default as MapControls } from './MapControls';
export type { MapControlsProps } from './MapControls';

export { default as ZoomControl } from './ZoomControl';
export type { ZoomControlProps } from './ZoomControl';

export { default as LeafletMapPopup } from './LeafletMapPopup';
export type { LeafletMapPopupProps } from './LeafletMapPopup';
