import { connect } from 'react-redux';
import { MapOffset } from './MapOffset.component';

const mapStateToProps = (state) => ({
  sidebarOpened: state.ui.sidebar,
  analysisOpened: state.ui.analysisPanel,
});

export default connect(mapStateToProps)(MapOffset);
