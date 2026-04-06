import React from 'react';
import cx from 'classnames';
import { useSelector, useDispatch } from 'react-redux';
import { Popover, PopoverButton, PopoverPanel } from '@headlessui/react';
import { T } from '@transifex/react';
import type { RootState } from 'state/types';
import { setLabels } from 'state/modules/map';
import type { MAP_LABELS } from 'views/components/LayersList/Basemaps/constants';

type LabelValue = (typeof MAP_LABELS)[number];

const LABEL_OPTIONS: { value: LabelValue; labelKey: string }[] = [
  { value: 'dark', labelKey: 'Dark labels' },
  { value: 'light', labelKey: 'Light labels' },
  { value: 'none', labelKey: 'No labels' },
];

const LabelsButton: React.FC = () => {
  const labels = useSelector((state: RootState) => state.map.labels);
  const basemap = useSelector((state: RootState) => state.map.basemap);
  const dispatch = useDispatch();

  return (
    <Popover>
      {({ open }) => (
        <div className={cx('m-toolbar__item--popover', { 'is-open': open })}>
          <PopoverButton
            className="m-toolbar-item--button"
            aria-label="Change labels"
            title="Change labels"
          >
            <svg className="icon" viewBox="0 0 24 24" fill="currentColor" stroke="none">
              <text x="4" y="18" fontSize="16" fontWeight="bold" fontFamily="sans-serif">
                Aa
              </text>
            </svg>
          </PopoverButton>
          <PopoverPanel className="m-toolbar-item--panel m-toolbar-labels-panel">
            <div className="m-toolbar-labels-grid">
              {LABEL_OPTIONS.map(({ value, labelKey }) => (
                <button
                  key={value}
                  type="button"
                  className={cx('m-toolbar-labels-option', {
                    'is-active': labels === value,
                  })}
                  onClick={() => dispatch(setLabels(value))}
                >
                  <span className={`icon-labels-${basemap}-${value}`}>
                    <T _str={labelKey} />
                  </span>
                </button>
              ))}
            </div>
          </PopoverPanel>
        </div>
      )}
    </Popover>
  );
};

export default LabelsButton;
