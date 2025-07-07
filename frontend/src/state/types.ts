import type { FormStateMap } from 'redux-form';
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
  byId: Record<string, any>;
  all: string[];
  actives: string[];
}

export interface RootState {
  form: FormStateMap;
  ui: UIState;
  site: any;
  sites: any;
  siteScopeAuth: any;
  map_menu_entries: any;
  user: any;
  map: MapState;
  journeys: any;
  journey: any;
  indicators: any;
  layers: LayersState;
  layer_groups: LayerGroupsState;
  sources: {
    byId: Record<string, any>;
  };
  categories: any;
  models: any;
  homepage: any;
  homepage_sections: any;
  site_pages: any;
}
