import { connect } from 'react-redux';
import Component from './LogoAttribution.component';

const mapStateToProps = (state) => ({
  hasGEFLogo: state.site.has_gef_logo,
});

export default connect(mapStateToProps)(Component);
