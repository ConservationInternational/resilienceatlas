import { connect } from 'react-redux';
import { load as loadHomepage } from 'state/modules/homepage';

import HomepageSections from './HomepageSections.component';

const mapStateToProps = (state) => {
  return {
    homepage: state.homepage,
    homepageLoaded: state.homepage?.loaded,
  };
};

const mapDispatchToProps = {
  loadHomepage,
};

export default connect(mapStateToProps, mapDispatchToProps)(HomepageSections);
