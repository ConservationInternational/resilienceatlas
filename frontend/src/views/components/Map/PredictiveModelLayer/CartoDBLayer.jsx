import React, { useState, useEffect, useRef } from 'react';
import PropTypes from 'prop-types';
import L from 'leaflet';
import carto from '@carto/carto.js';

import Loader from '@shared/Loader';

const client = new carto.Client({
  username: 'ra',
  apiKey: '71f277686cad7295641d5e7aff533cf734420cca',
  serverUrl: 'https://cdb.resilienceatlas.org/user/{username}',
});

const CartoDBLayer = ({ map, onCreate, layer }: { map: L.Map }) => {
  const [loading, setLoading] = useState(false);
  const layerRef = useRef(null);

  useEffect(() => {
    setLoading(true);

    const source = new carto.source.SQL(layer.sql);
    const style = new carto.style.CartoCSS(layer.cartocss);

    const cartolayer = new carto.layer.Layer(source, style);

    client.addLayers([cartolayer]);

    client.getLeafletLayer().addTo(map);

    return () => {
      if (layerRef.current) {
        map.removeLayer(layerRef.current);
      }
    };
  }, []);

  if (loading) return <Loader loading />;

  return null;
};

CartoDBLayer.propTypes = {
  map: PropTypes.instanceOf(L.Map).isRequired,
  onCreate: PropTypes.func,
};

CartoDBLayer.defaultProps = {
  onCreate: null,
};

export default CartoDBLayer;
