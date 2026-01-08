import type { MAP_LABELS, BASEMAP_LABELS } from 'views/components/LayersList/Basemaps/constants';
import type { NextRouter } from 'next/router';

export interface MapViewProps {
  labels: (typeof MAP_LABELS)[number];
  basemap: (typeof BASEMAP_LABELS)[number];
  router: NextRouter;
  onLoadingLayers?: (loaded: boolean) => void;
  layers: {
    loaded: boolean;
    loadedLocale: string;
    loadedSubdomain: string;
  };
  layer_groups: {
    loaded: boolean;
    loadedLocale: string;
    loadedSubdomain: string;
  };
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  activeLayers: any[];
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  model_layer: any;
  defaultActiveGroups: string[];
  tab: string;
  site: {
    latitude: number;
    longitude: number;
    zoom_level: number;
  };
  page: string;
  options?: {
    map: {
      zoom: number;
      center: {
        lat: number;
        lng: number;
      };
      scrollWheelZoom: boolean;
      drawControl: boolean;
      minZoom: number;
      maxZoom: number;
    };
  };
  embed: boolean;
  drawing: boolean;
  // actions
  loadLayers: (locale: string) => void;
  loadLayerGroups: (locale: string) => void;
  openBatch: (defaultActiveGroups: string[]) => void;
  // interaction
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  setMapLayerGroupsInteraction: (e: any) => void;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  setMapLayerGroupsInteractionLatLng: (e: any) => void;
}

// Props that the connected component accepts (after HOCs)
export interface ConnectedMapViewProps {
  onLoadingLayers?: (loaded: boolean) => void;
  page?: string;
  options?: {
    map: {
      minZoom: number;
      maxZoom: number;
      zoomControl: boolean;
    };
  };
}
