import React from 'react';

const LegendBorder = ({ data }) => (
  <div className="m-legend__border">
    {(data || []).map(({ name, value }) => (
      <div key={name} className="item">
        <span style={{ borderColor: value }} />
        {name}
      </div>
    ))}
  </div>
);

export default LegendBorder;
