import React from 'react';
import { useRouterValue, useToggle, useTogglerButton, clickable } from 'utilities';
import cx from 'classnames';

const Basemaps = ({ basemap, setBasemap }) => {
  const [opened, toggleOpened] = useToggle(false);

  useRouterValue('basemap', basemap, { onlyOnChange: true });

  const { getTogglerProps } = useTogglerButton(basemap, setBasemap);

  return (
    <li>
      <div
        className={cx('m-layers-list-header', { 'is-active': opened })}
        {...clickable(toggleOpened)}
      >
        <div className="header-title theme-color">basemap</div>
      </div>
      <ul className={cx('m-basemap-selectors', { 'is-active': opened })}>
        <li>
          <button type="button" {...getTogglerProps('satellite')}>
            <span className="icon-satellite">Satellite</span>
          </button>
        </li>
        <li>
          <button type="button" {...getTogglerProps('topographic')}>
            <span className="icon-topographic">Topographic</span>
          </button>
        </li>
        <li>
          <button type="button" {...getTogglerProps('dark')}>
            <span className="icon-dark">Dark</span>
          </button>
        </li>
        <li>
          <button type="button" {...getTogglerProps('defaultmap')}>
            <span className="icon-default">Default</span>
          </button>
        </li>
      </ul>
    </li>
  );
};

export default Basemaps;
