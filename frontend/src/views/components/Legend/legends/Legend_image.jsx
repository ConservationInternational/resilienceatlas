import React from 'react';

const LegendImage = ({ units, image_src, image_width }) => (
  <>
    {units && <span className="units">{units}</span>}
    <div className="m-legend__image">
      <img src={image_src} width={image_width ? image_width : '200'}></img>
    </div>
  </>
);

export default LegendImage;
