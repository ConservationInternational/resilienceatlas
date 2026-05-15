import { useEffect } from 'react';
import { useSelector, useDispatch } from 'react-redux';
import { useRouterValue, getRouterParam } from 'utilities';
import { subdomain } from 'utilities/getSubdomain';
import { setBasemap, setLabels, setBoundaries } from 'state/modules/map';
import type { RootState } from 'state/types';
import type { BASEMAP_LABELS, MAP_LABELS } from 'views/components/LayersList/Basemaps/constants';

/**
 * Syncs basemap, labels, and boundaries state between Redux and URL params.
 * Must be called inside a component that is always mounted when the map is visible.
 */
export const useMapSettingsSync = () => {
  const basemap = useSelector((state: RootState) => state.map.basemap);
  const labels = useSelector((state: RootState) => state.map.labels);
  const boundaries = useSelector((state: RootState) => state.map.boundaries);
  const dispatch = useDispatch();

  // Sync basemap and labels from URL params after hydration to prevent hydration mismatch
  useEffect(() => {
    const urlBasemap = getRouterParam('basemap');
    const urlLabels = getRouterParam('labels') as (typeof MAP_LABELS)[number];

    const correctBasemap = urlBasemap || (subdomain === 'atlas' ? 'satellite' : 'defaultmap');
    const correctLabels = urlLabels || 'none';

    if (correctBasemap !== basemap) {
      dispatch(setBasemap(correctBasemap as (typeof BASEMAP_LABELS)[number]));
    }
    if (correctLabels !== labels) {
      dispatch(setLabels(correctLabels));
    }

    const urlBoundaries = getRouterParam('boundaries');
    if (urlBoundaries === 'true' && !boundaries) {
      dispatch(setBoundaries(true));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []); // Run only once after mount

  useRouterValue('basemap', basemap, { onlyOnChange: true });
  useRouterValue('labels', labels, { onlyOnChange: true });
  useRouterValue('boundaries', boundaries ? 'true' : null, { onlyOnChange: true });
};
