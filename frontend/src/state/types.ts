import type { MapState } from './modules/map/reducer';

export interface UIState {
  sidebar: boolean;
  analysisPanel: boolean;
  tab: string;
}

export interface LayerGroupsState {
  loaded: boolean;
  loadedLocale: string;
  loadedSubdomain: string;
}

export interface LayersState {
  loaded: boolean;
  loadedLocale: string;
  loadedSubdomain: string;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  byId: Record<string, any>;
  all: string[];
  actives: string[];
}

export interface RootState {
  ui: UIState;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  site: any;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  sites: any;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  siteScopeAuth: any;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  map_menu_entries: any;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  user: any;
  map: MapState;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  journeys: any;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  journey: any;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  indicators: any;
  layers: LayersState;
  layer_groups: LayerGroupsState;
  sources: {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    byId: Record<string, any>;
  };
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  categories: any;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  models: any;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  homepage: any;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  homepage_sections: any;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  site_pages: any;
}
