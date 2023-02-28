import { connect } from 'react-redux';
import { setGeojson, setDrawing, setISO } from '@modules/map';
import { getByISO } from '@modules/countries/selectors';

import { DrawingManager } from './DrawingManager.component';

const mapStateToProps = state => ({
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
};

export default connect(mapStateToProps, mapDispatchToProps)(DrawingManager);
