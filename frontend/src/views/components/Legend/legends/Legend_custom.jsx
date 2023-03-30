import React from 'react';

const LegendCustom = ({ units, data }) => (
  <>
    {units && <span className="units">{{ units }}</span>}
    <div className="m-legend__custom">
      {data.map((d) => (
        <div key={d.name} className="item">
          <span style={{ backgroundColor: d.value }} /> {d.name}
        </div>
      ))}
    </div>
  </>
);

export default LegendCustom;
