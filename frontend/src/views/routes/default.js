import React from 'react';
import { Switch, Route, Redirect } from 'react-router-dom';

import auth, { SHARED, LOGGED, UNLOGGED } from '../utils/authorization';
import { mainLayout, fullscreenLayout, reportLayout, embedLayout } from '../layouts';

import Welcome from '../pages/welcome';
import About from '../pages/about';
import Journeys from '../pages/journeys';
import MapPage from '../pages/map';
import EmbedMap from '../pages/embed/map';
import Report from '../pages/report';
import Journey from '../pages/journey';
import Login from '../pages/login';
import Signup from '../pages/signup';
import Me from '../pages/me';
import ProfileSettings from '../pages/profile-settings';
import ShinnyApp from '../pages/shinny-app';

import NotFound from '../pages/notfound';

const shared = auth(SHARED);
const logged = auth(LOGGED);
const unlogged = auth(UNLOGGED);

const Layout = {
  Welcome: mainLayout(Welcome),
  About: mainLayout(About),
  Journeys: mainLayout(Journeys),
  Journey: fullscreenLayout(Journey),
  Map: fullscreenLayout(MapPage),
  EmbedMap: embedLayout(EmbedMap),
  Report: reportLayout(Report),
  Login: mainLayout(Login),
  Signup: mainLayout(Signup),
  Me: mainLayout(Me),
  ProfileSettings: mainLayout(ProfileSettings),
  ShinnyApp: mainLayout(ShinnyApp),
};

const Auth = {
  Welcome: shared(Layout.Welcome),
  About: shared(Layout.About),
  Journeys: shared(Layout.Journeys),
  Journey: shared(Layout.Journey),
  Map: shared(Layout.Map),
  EmbedMap: shared(Layout.EmbedMap),
  Report: shared(Layout.Report),
  Login: unlogged(Layout.Login),
  Signup: unlogged(Layout.Signup),
  Me: logged(Layout.Me),
  ProfileSettings: logged(Layout.ProfileSettings),
  ShinnyApp: shared(Layout.ShinnyApp),
};

const DefaultRoutes = () => (
  <Switch>
    <Route exact path="/" component={Auth.Welcome} />
    <Route exact path="/about" component={Auth.About} />
    <Route exact path="/journeys" component={Auth.Journeys} />
    <Route exact path="/map" component={Auth.Map} />
    <Route exact path="/report" component={Auth.Report} />

    <Redirect exact from="/journeys/:id" to="/journeys/:id/step/1" />
    <Redirect exact from="/journeys/:id/step" to="/journeys/:id/step/1" />

    <Route exact path="/journeys/:id/step/:step" component={Auth.Journey} />

    <Route exact path="/embed/map" component={Auth.EmbedMap} />

    <Route exact path="/login" component={Auth.Login} />
    <Route exact path="/register" component={Auth.Signup} />

    <Route exact path="/me" component={Auth.Me} />
    <Route exact path="/profile-settings" component={Auth.ProfileSettings} />
    <Route exact path="/shinny-app" component={Auth.ShinnyApp} />

    <Route component={NotFound} />
  </Switch>
);

export default DefaultRoutes;
