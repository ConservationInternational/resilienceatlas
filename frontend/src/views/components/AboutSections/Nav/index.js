import NavComponent from './Nav.component';
import { connect } from 'react-redux';

const mapStateToProps = (state) => ({
  translations: state.translations.data,
});

export default connect(mapStateToProps, null)(NavComponent);
