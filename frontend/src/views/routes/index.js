import React from 'react';

import { subdomain } from '@utilities/getSubdomain';

import AtlasRoutes from './atlas';
import DefaultRoutes from './default';

const Routes = () => {
  if (
    subdomain &&
    subdomain.toLowerCase() !== 'www' &&
    subdomain.toLowerCase() !== 'staging-cigrp'
  ) {
    return <AtlasRoutes />;
  }
  return <DefaultRoutes />;
};

export default Routes;
