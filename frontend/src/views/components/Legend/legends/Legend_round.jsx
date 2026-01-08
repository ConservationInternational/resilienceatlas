import React from 'react';

const LegendRound = ({ units, bubble, data }) => (
  <>
    {units && <span className="units">{{ units }}</span>}
    <div className="m-legend__round">
      {bubble && (
        <div className="bubble">
          <div className="min">{bubble.min}</div>
          <div className="bubble-list">
            <div className="bubble-1" />
            <div className="bubble-2" />
            <div className="bubble-3" />
            <div className="bubble-4" />
            <div className="bubble-5" />
          </div>
          <div className="max">{bubble.max}</div>
        </div>
      )}

      {(data || []).map((d) => (
        <div key={d.name} className="item">
          <span style={{ backgroundColor: d.value }} /> {d.name}
        </div>
      ))}
    </div>
  </>
);

export default LegendRound;
