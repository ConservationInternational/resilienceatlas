import React, { Fragment, useEffect, useMemo } from 'react';
import qs from 'qs';
import Loader from 'views/shared/Loader';
import { T } from '@transifex/react';
import { useRouterParams } from 'utilities';

import Indicator from './Indicator';

const PredictiveModels = ({
  // actions
  loadModels,
  select,
  applyIndicators,
  resetIndicators,
  // data
  models,
  model,
  indicatorsState,
  modelsLoading,
  modelsLoaded,
  selectedModel,
}) => {
  const { setParam } = useRouterParams();

  useEffect(() => {
    if (!modelsLoaded) loadModels();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    // detect only changes caused by user
    if (model) {
      setParam(
        'model',
        qs.stringify(
          {
            name: selectedModel,
            values: model.indicators.map((ind) => ind.indexableValue),
          },
          {
            arrayFormat: 'comma',
          },
        ),
      );
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [model, indicatorsState]);

  const hasChanged = useMemo(
    () =>
      model && model.indicators.some((ind, index) => ind.indexableValue !== indicatorsState[index]),
    [model, indicatorsState],
  );

  const notDefault = useMemo(
    () => model && model.indicators.some((ind) => +ind.indexableValue !== 4),
    [model],
  );

  // const text = "Select a combination of interventions. There are nine levels: extremely, very, strongly and moderately less important, equally, and moderately, strongly, very and extremely more important."

  return (
    <div className="m-predictive-models">
      <Loader loading={modelsLoading} />
      <div className="model-selector">
        <select
          className="js-model-selector"
          aria-label={<T _str="Select a model" />}
          value={selectedModel || 'default'}
          onChange={(e) => select(e.currentTarget.value)}
        >
          <option disabled value="default">
            <T _str="Select a model" />
          </option>
          {models.map(({ id, name }) => (
            <option key={id} value={id}>
              {name}
            </option>
          ))}
        </select>
      </div>

      {!!model && (
        <ul className="indicators-list">
          {model.categories.map(({ name, indicators }) => (
            <Fragment key={name}>
              <li className="category">{name}</li>

              {indicators.map((indicator) => (
                <Indicator
                  key={indicator.name}
                  index={model.indicators.findIndex((ind) => ind.id === indicator.id)}
                  {...indicator}
                />
              ))}
            </Fragment>
          ))}
        </ul>
      )}

      <div className="actions" hidden={!model}>
        <button
          type="button"
          disabled={!notDefault}
          className="btn btn-small -secondary"
          onClick={resetIndicators}
        >
          <T _str="Reset" />
        </button>
        <button
          type="button"
          disabled={!hasChanged}
          className="btn btn-small -primary"
          onClick={applyIndicators}
        >
          <T _str="Apply" />
        </button>
      </div>
    </div>
  );
};

export default PredictiveModels;
