import { createSelector } from 'reselect';
import { denormalize } from 'normalizr';
import { model } from '../../schema';

export const getSelected = state => state.predictive_models.selected;

export const getModels = state => state.predictive_models.byId;

export const getCategoies = state => state.predictive_models.categories;

export const getIndicators = state => state.predictive_models.indicators;

export const getIds = state => state.predictive_models.all;

export const makeAll = () =>
  createSelector(
    [getIds, getModels, getCategoies, getIndicators],
    (all, models, categories, indicators) =>
      denormalize(all, [model], { models, categories, indicators }),
  );

export const makeActive = () => {
  const getAll = makeAll();

  return createSelector(
    [getAll, getSelected, getCategoies],
    (models, selected, categoriesById) => {
      const selectedModel = models.find(m => m.id === selected);
      if (!selected || !selectedModel) return null;

      const { indicators } = selectedModel;
      const categoriesIds = [...new Set(indicators.map(ind => ind.category))];
      const categories = categoriesIds
        .map(catId => categoriesById[catId])
        .map(category => ({
          name: category.name,
          indicators: indicators.filter(ind => ind.category === category.id),
        }));

      return {
        ...selectedModel,
        categories,
      };
    },
  );
};

export const makeLayer = () => {
  const getActive = makeActive();

  return createSelector([getActive], activeModel => {
    if (!activeModel) return null;
    const columns = activeModel.indicators
      .filter(
        indicator => indicator.value !== null && indicator.value !== undefined,
      )
      .map(ind => {
        const weight = ind.value % 1 === 0 ? ind.value : ind.value.toFixed(3);

        return `{ 
            "column_name": "${ind.column}", 
            "weight": ${weight}, 
            "operation": "${ind.operation || '+'}" 
          }`;
      });

    const cartocss = `#intensification_reduce{
        polygon-fill: #A53ED5;
        polygon-opacity: 1;
        line-color: #A53ED5;
        line-width: 0.5;
        line-opacity: 1;
      }
      #intensification_reduce [ value <= 100] {
        polygon-fill: #B10026;
        line-color: #B10026;
      }
      #intensification_reduce [ value <= 0.8] {
        polygon-fill: #E31A1C;
        line-color: #E31A1C;
      }
      #intensification_reduce [ value <= 0.5] {
        polygon-fill: #FC4E2A;
        line-color: #FC4E2A;
      }
      #intensification_reduce [ value <= 0.3] {
        polygon-fill: #FD8D3C;
        line-color: #FD8D3C;
      }
      #intensification_reduce [ value <= 0.1] {
        polygon-fill: #FEB24C;
        line-color: #FEB24C;
      }
      #intensification_reduce [ value <= 0.01] {
        polygon-fill: #FED976;
        line-color: #FED976;
      }
      #intensification_reduce [ value <= 0] {
        polygon-fill: #FFFFB2;
        line-color: #FFFFB2;
      }`;

    const sql = `select * from getModel('${activeModel.tableName}', '[${columns}]')`;

    return {
      id: -1,
      slug: 'predictive-model-layer',
      name: activeModel.name,
      type: 'cartodb',
      description: `{
          "description": "${activeModel.description || ''}", 
          "source": "${activeModel.source || ''}"
        }`,
      cartocss,
      interactivity: '',
      sql,
      color: '',
      opacity: 1,
      no_opacity: false,
      order: 1,
      maxZoom: 25,
      minZoom: 0,
      legend: `{
            "type": "choropleth",\r\n
            "min":"0",\r\n
            "mid": "0.5",\r\n
            "max":"1",\r\n
            "bucket":["#FFFFB2","#FED976","#FEB24C","#FD8D3C"," #FC4E2A","#E31A1C","#B10026"]
          }`,
      group: -1,
      active: true,
      published: true,
      info: `{
          "description":"${activeModel.description || ''}", 
          "source":"${activeModel.source || ''}"
        }`,
      dashboard_order: null,
      download: false,
      dataset_shortname: null,
      dataset_source_url: null,
      attributions: false,
      // for layer-manager
      provider: 'cartodb',
      layerProvider: 'cartodb',
      layerConfig: {
        account: 'cdb',
        body: {
          layers: [
            {
              type: 'mapnik',
              options: {
                cartocss,
                sql,
                cartocss_version: '2.1.0',
              },
            },
          ],
          minzoom: 0,
          maxzoom: 25,
        },
      },
    };
  });
};
