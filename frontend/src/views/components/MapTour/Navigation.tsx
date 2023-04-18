import React, { useCallback } from 'react';
import { T } from '@transifex/react';

import type { components } from '@reactour/tour';

type NavigationProps = (typeof components)['Navigation'];

const MapTourNavigation: NavigationProps = ({ steps, currentStep, setCurrentStep, setIsOpen }) => {
  const stepsLength = steps.length;
  const isLastStep = currentStep === stepsLength - 1;

  const handleClose = useCallback(() => setIsOpen(false), [setIsOpen]);
  const handleNext = useCallback(
    () => setCurrentStep(currentStep + 1),
    [currentStep, setCurrentStep],
  );

  return (
    <div className="map-tour-navigation">
      {!isLastStep && (
        <button
          type="button"
          onClick={handleNext}
          disabled={isLastStep}
          data-testid="map-tour-next-button"
        >
          <T _str="Next" />
        </button>
      )}
      {!isLastStep && (
        <button
          type="button"
          className="skip-button"
          onClick={handleClose}
          data-testid="map-tour-skip-button"
        >
          <T _str="Skip" />
        </button>
      )}
      {isLastStep && (
        <button
          type="button"
          className="skip-button"
          onClick={handleClose}
          data-testid="map-tour-close-button"
        >
          <T _str="Close" />
        </button>
      )}
    </div>
  );
};

export default MapTourNavigation;
