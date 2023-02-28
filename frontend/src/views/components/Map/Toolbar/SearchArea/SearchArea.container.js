import { connect } from 'react-redux';

import { fitBounds } from '@modules/map';
import { makeCountries } from '@modules/countries';

import SearchArea from './SearchArea.component';

const makeMapStateToProps = () => {
  const getCountries = makeCountries();

  const mapStateToProps = state => ({
    countries: getCountries(state),
  });

  return mapStateToProps;
};

const mapDispatchToProps = {
  fitBounds,
};

export default connect(makeMapStateToProps, mapDispatchToProps)(SearchArea);
