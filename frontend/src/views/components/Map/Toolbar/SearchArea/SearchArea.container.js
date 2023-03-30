import { connect } from 'react-redux';

import { fitBounds } from 'state/modules/map';
import { makeCountries } from 'state/modules/countries';

import SearchArea from './SearchArea.component';

const makeMapStateToProps = () => {
  const getCountries = makeCountries();

  const mapStateToProps = (state) => ({
    countries: getCountries(state),
  });

  return mapStateToProps;
};

const mapDispatchToProps = {
  fitBounds,
};

export default connect(makeMapStateToProps, mapDispatchToProps)(SearchArea);
