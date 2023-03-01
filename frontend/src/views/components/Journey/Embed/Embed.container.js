import { connect } from 'react-redux';

import {
  load as loadLayers,
  setActives as setActiveLayer,
} from '@modules/layers';
import { load as loadCountries, makeCountries } from '@modules/countries';

import JourneyEmbed from './Embed.component';

const makeMapStateToProps = () => {
  const getCountries = makeCountries();

  const mapStateToProps = state => ({
    countries: getCountries(state),
    countriesLoaded: state.countries.loaded,
    countryName: state.journey.data.title,
  });

  return mapStateToProps;
};
const mapDispatchToProps = {
  loadCountries,
  loadLayers,
  setActiveLayer,
};

export default connect(makeMapStateToProps, mapDispatchToProps)(JourneyEmbed);
