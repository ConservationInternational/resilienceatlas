import { connect } from 'react-redux';

import {
  toggleSidebar as toggleOpen,
  toggleAnalysis,
  setTab,
} from '@modules/ui';

import Sidebar from './Sidebar.component';

const mapStateToProps = state => ({
  tab: state.ui.tab,
  geojson: state.map.geojson,
  opened: state.ui.sidebar,
  analysisOpened: state.ui.analysisPanel,
  models: state.predictive_models.all,
  modelsLoaded: state.predictive_models.loaded,
  site: state.site,
});

const mapDispatchToProps = {
  toggleOpen,
  toggleAnalysis,
  setTab,
};

export default connect(mapStateToProps, mapDispatchToProps)(Sidebar);
