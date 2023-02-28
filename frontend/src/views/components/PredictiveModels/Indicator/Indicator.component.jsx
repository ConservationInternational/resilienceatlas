import React from 'react';
import cx from 'classnames';

import {
  getIndexableIndicatorValueRange,
  getValueDescriptionFromIndex,
  getHumanReadableIndicatorValueFromIndex,
} from '@modules/predictive_models/utils';
import { useInput, useDebounce } from '@utilities/hooks';

const [min, max] = getIndexableIndicatorValueRange();
const indicatorRange = { min, max };

const Indicator = ({
  updateIndicator,
  toggleIndicator,
  name,
  id,
  stateValue,
  index,
}) => {
  const slider = useInput(name, stateValue);
  const valueExists = typeof stateValue === 'number';
  const leftOffset = (slider.value / indicatorRange.max) * 100;
  const handleSize = 12;

  useDebounce(
    () => {
      if (valueExists && slider.value !== stateValue) {
        updateIndicator(+slider.value);
      }
    },
    300,
    [slider.value],
  );

  return (
    <li key={id}>
      <div className="m-form-input--switch">
        <input
          type="checkbox"
          className="js-indicator-toggle"
          data-indicator={name}
          id={`indicator-${id}`}
          value={id}
          checked={valueExists}
          onChange={() => toggleIndicator(index)}
        />
        <label htmlFor={`indicator-${id}`} aria-label={name} />
        {name}
      </div>
      {valueExists && (
        <div
          className={cx('m-form-input--slider', {
            hidden: !valueExists,
          })}
        >
          <div className="slider-wrapper">
            <input
              type="range"
              data-indicator={id}
              min={indicatorRange.min}
              max={indicatorRange.max}
              step="1"
              {...slider}
            />
            <span
              className="opacity"
              style={{
                width: `${leftOffset}%`,
              }}
            />
            <span
              className="tooltip"
              style={{
                left: `calc(${leftOffset}% - ${(leftOffset * handleSize) /
                  100}px + ${handleSize / 2}px)`,
              }}
            >
              {getValueDescriptionFromIndex(slider.value)}
            </span>
          </div>
          <div className="value">
            <input
              type="text"
              className="opacity-teller"
              value={getHumanReadableIndicatorValueFromIndex(slider.value)}
              disabled
            />
          </div>
        </div>
      )}
    </li>
  );
};

export default Indicator;
