import { connect } from 'react-redux';

import Landing from './component';

const mapStateToProps = (state) => ({
  landingInfo: state.journey.steps,
});

export default connect(mapStateToProps)(Landing);
