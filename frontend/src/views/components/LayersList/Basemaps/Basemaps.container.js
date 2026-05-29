import { connect } from 'react-redux';
import { setBasemap, setLabels, setBoundaries, setBoundaryStyle } from 'state/modules/map';

import Basemaps from './Basemaps.component';

const mapStateToProps = (state) => ({
  basemap: state.map.basemap,
  labels: state.map.labels,
  boundaries: state.map.boundaries,
  boundaryStyle: state.map.boundaryStyle,
});

const mapDispatchToProps = {
  setBasemap,
  setLabels,
  setBoundaries,
  setBoundaryStyle,
};

export default connect(mapStateToProps, mapDispatchToProps)(Basemaps);
