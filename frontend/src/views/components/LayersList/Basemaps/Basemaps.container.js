import { connect } from 'react-redux';
import { setBasemap, setLabels } from 'state/modules/map';

import Basemaps from './Basemaps.component';

const mapStateToProps = (state) => ({
  basemap: state.map.basemap,
  labels: state.map.labels,
});

const mapDispatchToProps = {
  setBasemap,
  setLabels,
};

export default connect(mapStateToProps, mapDispatchToProps)(Basemaps);
