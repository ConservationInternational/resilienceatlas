import React, { useRef, useEffect } from 'react';
import { MapPopup as VizzMapPopup } from 'vizzuality-components';
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
    <VizzMapPopup
      map={map}
      latlng={layerGroupsInteractionLatLng}
      data={{
        layers: layersInteraction,
        layersInteraction: layerGroupsInteraction,
        layersInteractionSelected: layerGroupsInteractionSelected,
      }}
      onReady={popup => {
        popupRef.current = popup;
      }}
    >
      <LayerPopup
        onChangeInteractiveLayer={selected => {
          setMapLayerGroupsInteractionSelected(selected);
        }}
      />
    </VizzMapPopup>
  );
};

export default MapPopup;
