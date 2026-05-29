import React from 'react';
import cx from 'classnames';
import { useSelector, useDispatch } from 'react-redux';
import { Popover, PopoverButton, PopoverPanel } from '@headlessui/react';
import { T } from '@transifex/react';
import type { RootState } from 'state/types';
import { setBoundaryStyle, setBoundaries } from 'state/modules/map';
import type { BOUNDARY_STYLES } from 'views/components/LayersList/Basemaps/constants';

type BoundaryValue = (typeof BOUNDARY_STYLES)[number];

const BOUNDARY_OPTIONS: { value: BoundaryValue; labelKey: string }[] = [
  { value: 'dark', labelKey: 'Dark boundaries' },
  { value: 'light', labelKey: 'Light boundaries' },
  { value: 'none', labelKey: 'No boundaries' },
];

const BoundariesButton: React.FC = () => {
  const boundaryStyle = useSelector((state: RootState) => state.map.boundaryStyle);
  const dispatch = useDispatch();

  const handleSelect = (value: BoundaryValue) => {
    dispatch(setBoundaryStyle(value));
    dispatch(setBoundaries(value !== 'none'));
  };

  return (
    <Popover>
      {({ open }) => (
        <div className={cx('m-toolbar__item--popover', { 'is-open': open })}>
          <PopoverButton
            className={cx('m-toolbar-item--button', 'm-toolbar-boundaries-btn', {
              'is-active': boundaryStyle !== 'none',
            })}
            aria-label="Change boundary style"
            title="Change boundary style"
          >
            {/* Irregular dashed polygon resembling a country silhouette */}
            <svg className="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
              <path
                d="M6 3L10 4L14 2L19 5L21 10L19 15L21 19L17 22L12 20L7 22L3 18L4 13L2 9L4 5Z"
                strokeDasharray="3 2"
                strokeLinejoin="round"
              />
            </svg>
          </PopoverButton>
          <PopoverPanel className="m-toolbar-item--panel m-toolbar-boundaries-panel">
            <ul className="m-toolbar-boundaries-list">
              {BOUNDARY_OPTIONS.map(({ value, labelKey }) => (
                <li key={value}>
                  <button
                    type="button"
                    className={cx('m-toolbar-boundaries-option', {
                      'is-active': boundaryStyle === value,
                    })}
                    onClick={() => handleSelect(value)}
                  >
                    <T _str={labelKey} />
                  </button>
                </li>
              ))}
            </ul>
          </PopoverPanel>
        </div>
      )}
    </Popover>
  );
};

export default BoundariesButton;
