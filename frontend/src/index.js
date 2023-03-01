import React from 'react';
import ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
import { Router } from 'react-router-dom';
import ReactGA from 'react-ga';

import App from './views/routes';
import store from './state/store';
import history from './history';
import * as serviceWorker from './serviceWorker';

import './views/styles/index.scss';

import 'leaflet';
import 'leaflet.pm';
import 'leaflet-active-area';
import 'leaflet-utfgrid/L.UTFGrid-min';

import 'leaflet.pm/dist/leaflet.pm.css';

import { load as loadSite } from './state/modules/site';
import { getToken, login } from './state/modules/user';

const userToken = getToken();

if (userToken) {
  store.dispatch(login(userToken));
}

store.dispatch(loadSite()).then(() => {
  const currentState = store.getState();
  const analyticsCode = currentState.site.analytics_code;

  if (analyticsCode) ReactGA.initialize(analyticsCode);
});

ReactDOM.render(
  <Provider store={store}>
    <Router history={history}>
      <App />
    </Router>
  </Provider>,
  document.getElementById('root'),
);
// If you want your app to work offline and load faster, you can change
// unregister() to register() below. Note this comes with some pitfalls.
// Learn more about service workers: https://bit.ly/CRA-PWA
serviceWorker.unregister();
