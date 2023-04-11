import type { StepType } from '@reactour/tour';

const TOUR_STEPS: StepType[] = [
  {
    selector: '.wri_api__map-controls-list',
    content: 'Use the basic map tools to zoom in and out, find a location, and share what you see.',
  },
  {
    selector: '.m-legend',
    content:
      'View and change the order of the data layers on the map. Click the "i" icons to learn more about a dataset.',
  },
  {
    selector: '.l-sidebar-content',
    content: () => (
      <>
        <p>
          Configure your map and explore available data layers by clicking on each category to view
          the available datasets within each dropdown.
        </p>
        <p>
          Click the button to the left of the dataset to view the layer. Click the &quote;i&quote;
          button for more information, the raindrop icon to adjust the transparency, and the
          double-sided arrow to zoom to the dataset&apos;s geographical extent.
        </p>
      </>
    ),
  },
  {
    selector: '.btn-analysis-panel-expand',
    content: 'Select a location to generate an analysis based on the active layers.',
  },
];

export default TOUR_STEPS;
