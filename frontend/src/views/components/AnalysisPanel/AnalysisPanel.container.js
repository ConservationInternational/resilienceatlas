import { connect } from 'react-redux';
import { compose } from 'redux';
import { withRouter } from 'next/router';

import { setDrawing, setGeojson, setISO } from 'state/modules/map';
import { load as loadCountries, makeCountries } from 'state/modules/countries';

import { AnalysisPanel } from './AnalysisPanel.component';

const mapStateToProps = (state) => {
  const getCountries = makeCountries();

  return {
    countries: getCountries(state),
    countriesLoaded: state.countries.loaded,
    drawing: state.map.drawing,
    geojson: state.map.geojson,
    iso: state.map.iso,
    translations: state.translations.data,
  };
};

const mapDispatchToProps = {
  loadCountries,
  setDrawing,
  setGeojson,
  setISO,
};

const withConnect = connect(mapStateToProps, mapDispatchToProps);

export default compose(withRouter, withConnect)(AnalysisPanel);
