import { connect } from 'react-redux';
import { makeActives } from '@modules/layers';
import { getByISO } from '@modules/countries/selectors';
import { LayerAnalysis } from './LayerAnalysis.component';

const makeMapStateToProps = () => {
  const getActives = makeActives();

  const mapStateToProps = state => ({
    activeLayers: getActives(state),
    loaded: state.layers.loaded,
    geojson: state.map.geojson,
    iso: state.map.iso,
    countries: getByISO(state),
  });

  return mapStateToProps;
};

export default connect(makeMapStateToProps)(LayerAnalysis);
