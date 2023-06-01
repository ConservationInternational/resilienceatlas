import { connect } from 'react-redux';

import {
  load as loadLayers,
  setActives as setActiveLayer,
  makeActives,
} from 'state/modules/layers';
import JourneyEmbed from './Embed.component';

const makeMapStateToProps = () => {
  const getActives = makeActives();

  const mapStateToProps = (state) => ({
    countryName: state.journey.data.attributes.title,
    layersLoaded: state.layers.loaded,
    activeLayers: getActives(state),
    layersLocaleLoaded: state.layers.localeLoaded,
    layersSubdomainLoaded: state.layers.subdomainLoaded,
  });

  return mapStateToProps;
};
const mapDispatchToProps = {
  loadLayers,
  setActiveLayer,
};

export default connect(makeMapStateToProps, mapDispatchToProps)(JourneyEmbed);
