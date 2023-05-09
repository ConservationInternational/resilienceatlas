import { connect } from 'react-redux';

import { load as loadLayers, setActives as setActiveLayer } from 'state/modules/layers';
import { load as loadCountries, makeCountries } from 'state/modules/countries';

import JourneyEmbed from './Embed.component';

const makeMapStateToProps = () => {
  const getCountries = makeCountries();

  const mapStateToProps = (state) => ({
    countries: getCountries(state),
    countriesLoaded: state.countries.loaded,
    countryName: state.journey.data.attributes.title,
    layersLoaded: state.layers.loaded,
    layersLocaleLoaded: state.layers.localeLoaded,
    layersSubdomainLoaded: state.layers.subdomainLoaded,
  });

  return mapStateToProps;
};
const mapDispatchToProps = {
  loadCountries,
  loadLayers,
  setActiveLayer,
};

export default connect(makeMapStateToProps, mapDispatchToProps)(JourneyEmbed);
