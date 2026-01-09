import React, { useRef, useEffect } from 'react';
import { LeafletMapPopup } from '../LeafletMap/exports';
import LayerPopup from './LayerPopup';

const MapPopup = ({
  setMapLayerGroupsInteractionSelected,
  map,
  layersInteraction,
  layerGroupsInteraction,
  layerGroupsInteractionSelected,
  layerGroupsInteractionLatLng,
}) => {
  const popupRef = useRef();

  useEffect(() => {
    if (popupRef.current) {
      popupRef.current.remove();
    }
  }, [layersInteraction.length]);

  return (
    <LeafletMapPopup
      map={map}
      latlng={layerGroupsInteractionLatLng}
      data={{
        layers: layersInteraction,
        layersInteraction: layerGroupsInteraction,
        layersInteractionSelected: layerGroupsInteractionSelected,
      }}
      onReady={(popup) => {
        popupRef.current = popup;
      }}
    >
      <LayerPopup
        onChangeInteractiveLayer={(selected) => {
          setMapLayerGroupsInteractionSelected(selected);
        }}
      />
    </LeafletMapPopup>
  );
};

export default MapPopup;
