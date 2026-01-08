import React from 'react';

const LegendChoropleth = ({ units, bucket, min, mid, max }) => (
  <>
    {units && <span className="units">{units}</span>}
    <div className="m-legend__choropleth">
      {min ? (
        <>
          {(bucket || []).map((b, i) => (
            <div key={i} className="item" style={{ backgroundColor: b }} />
          ))}
          <div className="numbers">
            <span>{min}</span>
            <span>{mid}</span>
            <span>{max}</span>
          </div>
        </>
      ) : (
        (bucket || []).map((b, i) => (
          <div key={i} className="wrapper-item">
            <span className="min-val">{b['min-value']}</span>
            <span className="max-val">{b['max-value']}</span>
            <div className="item" style={{ backgroundColor: b.color }} />
          </div>
        ))
      )}
    </div>
  </>
);

export default LegendChoropleth;
