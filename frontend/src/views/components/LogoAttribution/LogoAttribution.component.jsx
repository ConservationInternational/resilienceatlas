import React from 'react';
import { T } from '@transifex/react';

const LogoAttribution = ({ hasGEFLogo = false }) => {
  if (hasGEFLogo) {
    return (
      <div className="m-logo-attribution">
        <img src="/images/gef_green.jpg" alt={<T _str="Global Environment Facility" />} />
      </div>
    );
  }

  return null;
};

export default LogoAttribution;
