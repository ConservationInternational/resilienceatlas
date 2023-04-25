import { connect } from 'react-redux';
import { load as loadAbout } from 'state/modules/about';

import AboutSections from './AboutSections.component';

const mapStateToProps = (state) => {
  return {
    about: state.about?.data,
    aboutLoaded: state.about?.loaded,
    aboutLoadedLocale: state.about?.loadedLocale,
  };
};

const mapDispatchToProps = {
  loadAbout,
};

export default connect(mapStateToProps, mapDispatchToProps)(AboutSections);
