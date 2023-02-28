import React from 'react';

const LogoAttribution = ({ hasGEFLogo = false }) => {
  if (hasGEFLogo) {
    return (
      <div className="m-logo-attribution">
        <img src="/images/gef_green.jpg" alt="Global Environment Facility" />
      </div>
    );
  }

  return null;
};

export default LogoAttribution;
