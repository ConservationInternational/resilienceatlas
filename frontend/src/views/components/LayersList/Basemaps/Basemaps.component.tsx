import { useEffect, useMemo } from 'react';
import cx from 'classnames';
import { T, useLocale } from '@transifex/react';

import { useRouterValue, useToggle, useTogglerButton, clickable, getRouterParam } from 'utilities';
import { subdomain } from 'utilities/getSubdomain';
import {
  getMapLabelOptions,
  getBoundaryStyleOptions,
} from 'views/components/LayersList/Basemaps/constants';
import type { BASEMAP_LABELS, MAP_LABELS, BOUNDARY_STYLES } from 'views/components/LayersList/Basemaps/constants';

type BasemapsProps = {
  basemap: (typeof BASEMAP_LABELS)[number];
  labels: (typeof MAP_LABELS)[number];
  boundaries: boolean;
  boundaryStyle: (typeof BOUNDARY_STYLES)[number];
  setBasemap: (basemap: (typeof BASEMAP_LABELS)[number]) => void;
  setLabels: (labels: (typeof MAP_LABELS)[number]) => void;
  setBoundaries: (boundaries: boolean) => void;
  setBoundaryStyle: (boundaryStyle: (typeof BOUNDARY_STYLES)[number]) => void;
};

const Basemaps = ({
  basemap,
  labels,
  boundaries,
  boundaryStyle,
  setBasemap,
  setLabels,
  setBoundaries,
  setBoundaryStyle,
}: BasemapsProps) => {
  const [opened, toggleOpened] = useToggle(false);

  // Sync basemap and labels from URL params after hydration to prevent hydration mismatch
  useEffect(() => {
    const urlBasemap = getRouterParam('basemap');
    const urlLabels = getRouterParam('labels') as (typeof MAP_LABELS)[number];

    // Determine the correct basemap based on URL or subdomain
    const correctBasemap = urlBasemap || (subdomain === 'atlas' ? 'satellite' : 'defaultmap');
    const correctLabels = urlLabels || 'none';

    // Only update if different from current state
    if (correctBasemap !== basemap) {
      setBasemap(correctBasemap as (typeof BASEMAP_LABELS)[number]);
    }
    if (correctLabels !== labels) {
      setLabels(correctLabels);
    }

    // Handle boundary style from URL
    const urlBoundaryStyle = getRouterParam('boundaryStyle') as (typeof BOUNDARY_STYLES)[number];
    const correctBoundaryStyle = urlBoundaryStyle || 'none';
    
    if (correctBoundaryStyle !== boundaryStyle) {
      setBoundaryStyle(correctBoundaryStyle);
      setBoundaries(correctBoundaryStyle !== 'none');
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []); // Run only once after mount

  useRouterValue('basemap', basemap, { onlyOnChange: true });
  useRouterValue('labels', labels, { onlyOnChange: true });
  useRouterValue('boundaryStyle', boundaryStyle !== 'none' ? boundaryStyle : null, { onlyOnChange: true });

  const { getTogglerProps } = useTogglerButton(basemap, setBasemap);

  const locale = useLocale();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  const translatedLabels = useMemo(() => getMapLabelOptions(), [locale]);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  const translatedBoundaryStyles = useMemo(() => getBoundaryStyleOptions(), [locale]);

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
      <ul className={cx('m-labels-selectors', { 'is-active': opened })}>
        {translatedLabels.map(({ label, value }) => (
          <li key={value}>
            <div className="panel-item-switch m-form-input--switch label-option">
              <input
                type="checkbox"
                data-name={value}
                className="panel-input-switch"
                id={`label-${value}`}
                checked={value === labels}
                onChange={() => {
                  setLabels(value);
                }}
              />
              <label htmlFor={`label-${value}`} />
              <span>{label}</span>
            </div>
          </li>
        ))}
      </ul>
      <ul className={cx('m-boundaries-selectors', { 'is-active': opened })}>
        {translatedBoundaryStyles.map(({ label, value }) => (
          <li key={value}>
            <div className="panel-item-switch m-form-input--switch label-option">
              <input
                type="checkbox"
                data-name={value}
                className="panel-input-switch"
                id={`boundary-${value}`}
                checked={value === boundaryStyle}
                onChange={() => {
                  setBoundaryStyle(value);
                  setBoundaries(value !== 'none');
                }}
              />
              <label htmlFor={`boundary-${value}`} />
              <span>{label}</span>
            </div>
          </li>
        ))}
      </ul>
    </li>
  );
};

export default Basemaps;
