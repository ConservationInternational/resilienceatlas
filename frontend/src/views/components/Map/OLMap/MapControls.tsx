/**
 * Map Controls container component
 * Provides a container for map control elements (zoom, tools, etc.)
 */
import React, { type ReactNode } from 'react';

export interface MapControlsProps {
  customClass?: string;
  children?: ReactNode;
}

const MapControls: React.FC<MapControlsProps> = ({ customClass = '', children }) => {
  return <div className={`c-map-controls ${customClass}`}>{children}</div>;
};

export default MapControls;
