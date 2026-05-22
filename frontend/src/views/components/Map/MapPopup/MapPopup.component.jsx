import React, { useRef, useEffect } from 'react';
import { OLMapOverlay } from '../OLMap/exports';
import LayerPopup from './LayerPopup';

const MapPopup = ({
  setMapLayerGroupsInteractionSelected,
  map,
  layersInteraction,
  layerGroupsInteraction,
  layerGroupsInteractionSelected,
  layerGroupsInteractionLatLng,
}) => {
  const overlayRef = useRef();

  useEffect(() => {
    if (overlayRef.current) {
      overlayRef.current.setPosition(undefined);
    }
  }, [layersInteraction.length]);

  return (
    <OLMapOverlay
      map={map}
      latlng={layerGroupsInteractionLatLng}
      data={{
        layers: layersInteraction,
        layersInteraction: layerGroupsInteraction,
        layersInteractionSelected: layerGroupsInteractionSelected,
      }}
      onReady={(overlay) => {
        overlayRef.current = overlay;
      }}
    >
      <LayerPopup
        onChangeInteractiveLayer={(selected) => {
          setMapLayerGroupsInteractionSelected(selected);
        }}
        onClose={() => {
          if (overlayRef.current) {
            overlayRef.current.setPosition(undefined);
          }
        }}
      />
    </OLMapOverlay>
  );
};

export default MapPopup;
