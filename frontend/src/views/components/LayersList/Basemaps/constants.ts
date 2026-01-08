import { t } from '@transifex/native';

export const MAP_LABELS = ['dark', 'light', 'none'] as const;

export const getMapLabelOptions = () =>
  [
    {
      label: t('Dark labels'),
      value: 'dark',
    },
    {
      label: t('Light labels'),
      value: 'light',
    },
    {
      label: t('No labels'),
      value: 'none',
    },
  ] as { label: string; value: (typeof MAP_LABELS)[number] }[];

export const BASEMAP_LABELS = ['defaultmap', 'dark', 'satellite', 'topographic'] as const;
