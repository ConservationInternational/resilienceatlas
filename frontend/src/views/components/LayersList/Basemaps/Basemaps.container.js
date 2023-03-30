import { connect } from 'react-redux';
import { setBasemap } from 'state/modules/map';

import Basemaps from './Basemaps.component';

const mapStateToProps = (state) => ({
  basemap: state.map.basemap,
});

const mapDispatchToProps = {
  setBasemap,
};

export default connect(mapStateToProps, mapDispatchToProps)(Basemaps);
