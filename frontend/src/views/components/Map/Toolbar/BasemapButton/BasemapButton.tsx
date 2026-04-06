import React from 'react';
import cx from 'classnames';
import { useSelector, useDispatch } from 'react-redux';
import { Popover, PopoverButton, PopoverPanel } from '@headlessui/react';
import { T } from '@transifex/react';
import type { RootState } from 'state/types';
import { setBasemap } from 'state/modules/map';
import type { BASEMAP_LABELS } from 'views/components/LayersList/Basemaps/constants';

type BasemapValue = (typeof BASEMAP_LABELS)[number];

const BASEMAP_OPTIONS: { value: BasemapValue; labelKey: string; iconClass: string }[] = [
  { value: 'satellite', labelKey: 'Satellite', iconClass: 'icon-satellite' },
  { value: 'topographic', labelKey: 'Topographic', iconClass: 'icon-topographic' },
  { value: 'dark', labelKey: 'Dark', iconClass: 'icon-dark' },
  { value: 'defaultmap', labelKey: 'Default', iconClass: 'icon-default' },
];

const BasemapButton: React.FC = () => {
  const basemap = useSelector((state: RootState) => state.map.basemap);
  const dispatch = useDispatch();

  return (
    <Popover>
      {({ open }) => (
        <div className={cx('m-toolbar__item--popover', { 'is-open': open })}>
          <PopoverButton
            className="m-toolbar-item--button"
            aria-label="Change basemap"
            title="Change basemap"
          >
            <svg
              className="icon"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
            >
              <path d="M12 2L2 7l10 5 10-5-10-5z" />
              <path d="M2 17l10 5 10-5" />
              <path d="M2 12l10 5 10-5" />
            </svg>
          </PopoverButton>
          <PopoverPanel className="m-toolbar-item--panel m-toolbar-basemap-panel">
            <div className="m-toolbar-basemap-grid">
              {BASEMAP_OPTIONS.map(({ value, labelKey, iconClass }) => (
                <button
                  key={value}
                  type="button"
                  className={cx('m-toolbar-basemap-option', { 'is-active': basemap === value })}
                  onClick={() => dispatch(setBasemap(value))}
                >
                  <span className={iconClass}>
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

export default BasemapButton;
