import React from 'react';
import { T } from '@transifex/react';

const Outro: React.FC = () => {
  return (
    <div className="m-wizard-form__outro">
      <h2>
        <T _str="Thank you for filling out the survey." />
      </h2>
      <h1>
        <T _str="Your input is appreciated!" />
      </h1>
    </div>
  );
};

export default Outro;
