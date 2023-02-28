import React, { useReducer, useCallback, useEffect } from 'react';
import axios from 'axios';
import moment from 'moment';
import numeral from 'numeral';
import { replace } from 'resilience-layer-manager';

import createReducer from '@state/utils/createReducer';
import { createApiAction } from '@state/utils/api';
import { removeHtmlTags } from '@utilities/helpers';

const FETCH = createApiAction('FETCH');

const initialState = {
  interaction: {},
  loading: false,
};

const layerDataReducer = createReducer(initialState)({
  [FETCH.REQUEST]: state => ({
    ...state,
    interaction: {},
    loading: true,
  }),

  [FETCH.SUCCESS]: (state, action) => ({
    ...state,
    loading: false,
    interaction: {
      ...state.interaction,
      [action.payload.id]: action.payload,
    },
  }),

  [FETCH.FAIL]: state => ({
    ...state,
    loading: false,
  }),
});

const LayerPopup = ({
  onChangeInteractiveLayer,
  latlng,
  data: { layers, layersInteraction, layersInteractionSelected },
  popup,
}) => {
  const [state, dispatch] = useReducer(layerDataReducer, initialState);

  const formatValue = useCallback((item, data) => {
    if (item.type === 'date' && item.format && data) {
      data = moment(data).format(item.format);
    } else if (item.type === 'number' && item.format && data) {
      data = numeral(data).format(item.format);
    } else if (item.type === 'link' && data) {
      return <a href={data} target='_blank'> {data} </a>;
    }

    return `${item.prefix || ''}${removeHtmlTags(data) || '-'}${item.suffix ||
      ''}`;
  }, []);

  const layer = layersInteractionSelected
    ? layers.find(l => l.id === +layersInteractionSelected)
    : layers[0];

  if (!layer) {
    popup.remove();
    return null;
  }
  // Get interactionConfig
  const {
    interactionConfig: { output, config },
  } = layer;

  // Get data from props or state
  const interaction = layersInteraction[layer.id] || {};
  const interactionState = state.interaction[layer.id] || {};

  useEffect(() => {
    if (latlng && config && config.url) {
      dispatch({ type: FETCH.REQUEST });

      axios
        .get(replace(config.url, latlng), {})
        .then(({ data }) => {
          dispatch({
            type: FETCH.SUCCESS,
            payload: {
              ...layer,
              data: data && data.rows && data.rows[0],
            },
          });
        })
        .catch(() => {
          dispatch({ type: FETCH.FAIL });
        });
    }

    return () => {
      popup.remove();
    };
  }, []);

  return (
    <div className="c-map-popup">
      <header className="popup-header">
        <select
          className="popup-header-select"
          name="interactionLayers"
          value={layer.id}
          onChange={e => onChangeInteractiveLayer(e.target.value)}
        >
          {layers.map(o => (
            <option key={o.id} value={o.id}>
              {o.name}
            </option>
          ))}
        </select>
      </header>

      <div className="popup-content">
        {(interaction.data || interactionState.data) && (
          <table className="popup-table">
            <tbody>
              {output.map(outputItem => {
                const { column } = outputItem;
                const columnArray = column.split('.');
                const value = columnArray.reduce(
                  (acc, c) => acc[c],
                  interaction.data || interactionState.data,
                );
                return (
                  <tr
                    className="dc"
                    key={outputItem.property || outputItem.column}
                  >
                    <td className="dt">
                      {outputItem.property || outputItem.column}
                    </td>
                    <td className="dd">{ outputItem.column == 'image' ? <img src={value} width={outputItem.image_width ? outputItem.image_width : "100"}></img> : formatValue(outputItem, value)}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}

        {state.loading &&
          (!interaction.data || !interactionState.data) &&
          config &&
          config.url && <div className="popup-loader">Loading</div>}

        {!state.loading &&
          (!interaction.data && !interactionState.data) &&
          config &&
          config.url &&
          'No data available'}

        {!interaction.data &&
          !interactionState.data &&
          (!config || !config.url) &&
          'No data available'}
      </div>
    </div>
  );
};

export default LayerPopup;
