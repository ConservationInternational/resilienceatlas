import { connect } from 'react-redux';

import { load as loadLayers, setActives as setActiveLayer } from 'state/modules/layers';
import { load as loadCountries, makeCountries } from 'state/modules/countries';

import JourneyEmbed from './Embed.component';

const makeMapStateToProps = () => {
  const getCountries = makeCountries();
  const STATIC_JOURNEYS = process.env.NEXT_PUBLIC_STATIC_JOURNEYS === 'true';

  const mapStateToProps = (state) => ({
    countries: getCountries(state),
    countriesLoaded: state.countries.loaded,
    countryName: STATIC_JOURNEYS ? state.journey.data.title : state.journey.data.attributes.title,
    layersLoaded: state.layers.loaded,
    layersLocaleLoaded: state.layers.localeLoaded,
  });

  return mapStateToProps;
};
const mapDispatchToProps = {
  loadCountries,
  loadLayers,
  setActiveLayer,
};

export default connect(makeMapStateToProps, mapDispatchToProps)(JourneyEmbed);
