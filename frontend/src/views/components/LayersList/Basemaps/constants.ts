export const MAP_LABELS = ['dark', 'light', 'none'] as const;

export const MAP_LABELS_OPTIONS = [
  {
    label: 'Dark labels',
    value: 'dark',
  },
  {
    label: 'Light labels',
    value: 'light',
  },
  {
    label: 'No labels',
    value: 'none',
  },
] as { label: string; value: (typeof MAP_LABELS)[number] }[];

export const BASEMAP_LABELS = ['defaultmap', 'dark', 'satellite', 'topographic'] as const;
