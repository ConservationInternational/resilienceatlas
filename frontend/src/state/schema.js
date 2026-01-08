import { schema } from 'normalizr';
import { replace } from 'resilience-layer-manager';
import { generateDownloadUrl } from 'utilities/generateDownloadUrl';
import { birds } from './utils/decoders';

import {
  getIndexableIndicatorValue,
  getHumanReadableIndicatorValue,
} from './modules/predictive_models/utils';

const provider = {
  cartodb: 'carto',
  raster: 'carto',
  'xyz tileset': 'leaflet',
  cog: 'leaflet',
  gee: 'leaflet',
};

export const site_scope = new schema.Entity(
  'site_scopes',
  {},
  {
    processStrategy: (site) => ({
      id: site.id,
      ...site.attributes,
      pages: site.relationships.site_pages.data,
    }),
  },
);

export const layer = new schema.Entity(
  'layers',
  {},
  {
    processStrategy: (l) => {
      const getTimeline = () => ({
        defaultDate: new Date(l.attributes.timeline_default_date),
        endDate: new Date(l.attributes.timeline_end_date),
        startDate: new Date(l.attributes.timeline_start_date),
        period: l.attributes.timeline_period,
        steps: l.attributes.timeline_steps && l.attributes.timeline_steps.map((d) => new Date(d)),
      });

      const group = l.relationships.layer_group.data;
      const sourcesIds = l.relationships.sources.data.map((s) => s.id);
      const layerConfig = JSON.parse(l.attributes.layer_config || '{}');
      const config = {
        cartodb: {
          body: {
            layers: [
              {
                options: {
                  cartocss: l.attributes.css,
                  cartocss_version: '2.1.0',
                  sql: l.attributes.query,
                },
                type: 'mapnik',
              },
            ],
            minzoom: l.attributes.zoom_min,
            maxzoom: l.attributes.zoom_max,
          },
          account: 'cdb',
        },
        raster: {
          body: {
            layers: [
              {
                options: {
                  cartocss: l.attributes.css,
                  cartocss_version: '2.3.0',
                  sql: l.attributes.query,
                  raster: true,
                  raster_band: 1,
                  geom_column: 'the_raster_webmercator',
                  geom_type: 'raster',
                },
                type: 'cartodb',
              },
            ],
            minzoom: l.attributes.zoom_min,
            maxzoom: l.attributes.zoom_max,
          },
          account: 'cdb',
        },
        'xyz tileset': {
          type: 'tileLayer',
          body: {
            url: layerConfig?.body?.url,
          },
        },
        gee: {
          ...layerConfig,
          decodeFunction: birds,
          canvas: true,
        },
        // We need to manually parse the COG layer parameters because the layer manager doesn't support the object on colormap
        // COG layer_config can have url at root level or nested in body
        cog: (() => {
          const cogUrl = layerConfig?.body?.url || layerConfig?.url;
          const parsedUrl = cogUrl && replace(cogUrl, {
            ...layerConfig.params,
            colormap: layerConfig.params?.colormap
              ? encodeURIComponent(JSON.stringify(layerConfig.params.colormap))
              : null,
          });
          return {
            ...layerConfig,
            parse: false,
            type: layerConfig?.type || 'tileLayer',
            body: {
              ...(layerConfig?.body || {}),
              url: parsedUrl,
            },
          };
        })(),
      };

      return {
        id: parseInt(l.id, 10),
        slug: l.attributes.slug,
        name: l.attributes.name,
        type: l.attributes.layer_provider,
        cartocss: l.attributes.css,
        interactivity: l.attributes.interactivity,
        sql: l.attributes.query,
        color: l.attributes.color,
        // Opacity should start with 1 if it's missing
        opacity: l.attributes.opacity === null ? 1 : l.attributes.opacity,
        no_opacity: l.attributes.opacity === 0,
        order: l.attributes.order || null,
        maxZoom: l.attributes.zoom_max || 100,
        minZoom: l.attributes.zoom_min || 0,
        legend: l.attributes.legend,
        group: group ? parseInt(group.id, 10) : null,
        active: l.relationships.agrupation.data.active,
        published: l.attributes.published,
        description: l.attributes.description,
        dashboard_order: l.attributes.dashboard_order,
        download: l.attributes.download || null,
        download_url: l.attributes.download ? generateDownloadUrl(l) : null,
        dataset_shortname: l.attributes.dataset_shortname || null,
        dataset_source_url: l.attributes.dataset_source_url || null,
        sourceIds: sourcesIds && sourcesIds.length ? sourcesIds : null,
        analysisSuitable: l.attributes.analysis_suitable,
        analysisType: l.attributes.analysis_type,
        analysisQuery: l.attributes.analysis_query,
        analysisBody: l.attributes.analysis_body,
        analysisTextTemplate: l.attributes.analysis_text_template,
        layerProvider: l.attributes.layer_provider,
        timeline: l.attributes.timeline && getTimeline(),
        // Layer manager params
        provider: provider[l.attributes.layer_provider],
        layerConfig: config[l.attributes.layer_provider],
        decodeParams: l.attributes.layer_provider === 'gee' ? config.gee.decodeParams : null,
        decodeFunction: l.attributes.layer_provider === 'gee' ? config.gee.decodeFunction : null,
        params: l.attributes.layer_provider === 'gee' ? config.gee.params : {},
        interactionConfig: l.attributes.interaction_config,
      };
    },
  },
);

export const persisted_layer = new schema.Entity('persisted_layers');

export const layer_group = new schema.Entity(
  'layer_groups',
  {},
  {
    processStrategy: (lg) => {
      const superGroupId = lg.attributes.super_group_id;
      return {
        id: parseInt(lg.id, 10),
        slug: lg.attributes.slug,
        name: lg.attributes.name,
        father: superGroupId ? parseInt(superGroupId, 10) : null,
        order: lg.attributes.order,
        // active: lg.attributes.active,
        group_type: lg.attributes.layer_group_type,
      };
    },
  },
);

export const source = new schema.Entity(
  'sources',
  {},
  {
    processStrategy: (s) => ({
      id: parseInt(s.id, 10),
      ...s.attributes,
    }),
  },
);

export const country = new schema.Entity('countries', {}, { idAttribute: 'iso' });

export const category = new schema.Entity(
  'categories',
  {},
  {
    processStrategy: (cat) => ({
      id: cat.id,
      ...cat.attributes,
    }),
  },
);

export const indicator = new schema.Entity(
  'indicators',
  {},
  {
    processStrategy: (ind) => ({
      id: ind.id,
      name: ind.attributes.name,
      slug: ind.attributes.slug,
      version: ind.attributes.version,
      position: ind.attributes.position,
      column: ind.attributes.column_name,
      operation: ind.attributes.operation,
      value: 1,

      indexableValue: getIndexableIndicatorValue(1),
      humanReadableValue: getHumanReadableIndicatorValue(1),

      category: ind.relationships.category.data.id,
      models: ind.relationships.models.data.map((m) => m.id),
    }),
  },
);

export const model = new schema.Entity(
  'models',
  { indicators: [indicator], categories: [category] },
  {
    processStrategy: (mod) => ({
      id: mod.id,
      name: mod.attributes.name,
      description: mod.attributes.description,
      source: mod.attributes.source,
      tableName: mod.attributes.table_name,
      indicators:
        mod.relationships &&
        mod.relationships.indicators &&
        mod.relationships.indicators.data.map((d) => d.id),
    }),
  },
);

export const map_menu_entry = new schema.Entity(
  'map_menu_entries',
  {},
  {
    processStrategy: (entry) => ({
      id: entry.id,
      ...entry.attributes,
    }),
  },
);

export const journey = new schema.Entity('journeys');
