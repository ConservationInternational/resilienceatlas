import { connect } from 'react-redux';
import { setGeojson, setDrawing, setISO } from 'state/modules/map';
import { getByISO } from 'state/modules/countries/selectors';
import { loadGeometry } from 'state/modules/countries/actions';

import { DrawingManager } from './DrawingManager.component';

const mapStateToProps = (state) => ({
  drawing: state.map.drawing,
  geojson: state.map.geojson,
  iso: state.map.iso,
  bounds: state.map.bounds,
  countries: getByISO(state),
});

const mapDispatchToProps = {
  setGeojson,
  setDrawing,
  setISO,
  loadGeometry,
};

export default connect(mapStateToProps, mapDispatchToProps)(DrawingManager);
