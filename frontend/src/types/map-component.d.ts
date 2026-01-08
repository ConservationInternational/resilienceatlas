// Type augmentation for Map component to fix HOC typing issues
declare module 'views/components/Map' {
  import type { ConnectedMapViewProps } from 'views/components/Map/types';

  const MapView: React.ComponentType<ConnectedMapViewProps>;
  export default MapView;
}
