import React from 'react';
import cx from 'classnames';
import { useSelector, useDispatch } from 'react-redux';
import type { RootState } from 'state/types';
import { setBoundaries } from 'state/modules/map';

const BoundariesButton: React.FC = () => {
  const boundaries = useSelector((state: RootState) => state.map.boundaries);
  const dispatch = useDispatch();

  return (
    <button
      type="button"
      className={cx('m-toolbar-item--button', 'm-toolbar-boundaries-btn', {
        'is-active': boundaries,
      })}
      onClick={() => dispatch(setBoundaries(!boundaries))}
      aria-label={boundaries ? 'Hide country boundaries' : 'Show country boundaries'}
      title={boundaries ? 'Hide country boundaries' : 'Show country boundaries'}
    >
      {/* Irregular dashed polygon resembling a country silhouette */}
      <svg className="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
        <path
          d="M6 3L10 4L14 2L19 5L21 10L19 15L21 19L17 22L12 20L7 22L3 18L4 13L2 9L4 5Z"
          strokeDasharray="3 2"
          strokeLinejoin="round"
        />
      </svg>
    </button>
  );
};

export default BoundariesButton;
