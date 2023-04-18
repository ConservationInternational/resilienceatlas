import React from 'react';
import { useRouterValue, useToggle, useTogglerButton, clickable } from 'utilities';
import cx from 'classnames';
import { T } from '@transifex/react';

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
        <div className="header-title theme-color">
          <T _str="basemap" />
        </div>
      </div>
      <ul className={cx('m-basemap-selectors', { 'is-active': opened })}>
        <li>
          <button type="button" {...getTogglerProps('satellite')}>
            <span className="icon-satellite">
              <T _str="Satellite" />
            </span>
          </button>
        </li>
        <li>
          <button type="button" {...getTogglerProps('topographic')}>
            <span className="icon-topographic">
              <T _str="Topographic" />
            </span>
          </button>
        </li>
        <li>
          <button type="button" {...getTogglerProps('dark')}>
            <span className="icon-dark">
              <T _str="Dark" />
            </span>
          </button>
        </li>
        <li>
          <button type="button" {...getTogglerProps('defaultmap')}>
            <span className="icon-default">
              <T _str="Default" />
            </span>
          </button>
        </li>
      </ul>
    </li>
  );
};

export default Basemaps;
