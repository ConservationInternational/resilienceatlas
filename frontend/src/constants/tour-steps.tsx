import type { StepType } from '@reactour/tour';
import { T } from '@transifex/react';

const PADDING = 4;
const SPACE = 35 + PADDING;

const TOUR_STEPS: StepType[] = [
  {
    selector: '.wri_api__map-controls-list',
    content: () => (
      <T _str="Use the basic map tools to zoom in and out, find a location, and share what you see." />
    ),
    position: ({ top, left, width }) => [left - width - SPACE, top - PADDING],
  },
  {
    selector: '.m-legend',
    content: () => (
      <T _str='View and change the order of the data layers on the map. Click the "i" icons to learn more about a dataset.' />
    ),
    position: ({ top, width, windowWidth, height }) => [
      windowWidth - width - PADDING,
      top - height - SPACE,
    ],
  },
  {
    selector: '.l-sidebar-content',
    content: () => (
      <>
        <p>
          <T
            _str="Configure your map and explore available data layers by clicking on each category to view
          the available datasets within each dropdown."
          />
        </p>
        <p>
          <T
            _str='Click the button to the left of the dataset to view the layer. Click the "i"
          button for more information, the raindrop icon to adjust the transparency, and the
          double-sided arrow to zoom to the dataset&apos;s geographical extent.'
          />
        </p>
      </>
    ),
    position: ({ top, width, height }) => [width + SPACE, top + height / 2],
  },
  {
    selector: '.btn-analysis-panel-expand',
    content: () => (
      <T _str="Select a location to generate an analysis based on the active layers." />
    ),
    position: ({ top, left, width }) => [left - width / 2 + 46, top + 73],
  },
];

export default TOUR_STEPS;
