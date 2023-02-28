import React, { useRef } from 'react';

const LayerManagerContext = React.createContext();

const LayerManagerProvider = ({ children }) => {
  const layerManagerRef = useRef();

  return (
    <LayerManagerContext.Provider value={layerManagerRef}>
      {children}
    </LayerManagerContext.Provider>
  );
};

export { LayerManagerContext, LayerManagerProvider };
