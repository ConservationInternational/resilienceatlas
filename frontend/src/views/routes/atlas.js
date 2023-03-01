import React from 'react';
import { Switch, Route, Redirect } from 'react-router-dom';

import auth, { SHARED } from '../utils/authorization';
import { fullscreenLayout, reportLayout } from '../layouts';

import MapPage from '../pages/map';
import Report from '../pages/report';

import NotFound from '../pages/notfound';

const shared = auth(SHARED);

const Layout = {
  Map: fullscreenLayout(MapPage),
  Report: reportLayout(Report),
};

const Auth = {
  Map: shared(Layout.Map),
  Report: shared(Layout.Report),
};

const AtlasRoutes = () => (
  <Switch>
    <Redirect exact from="/" to="/map" />
    <Route exact path="/map" component={Auth.Map} />
    <Route exact path="/report" component={Auth.Report} />

    <Route component={NotFound} />
  </Switch>
);

export default AtlasRoutes;
