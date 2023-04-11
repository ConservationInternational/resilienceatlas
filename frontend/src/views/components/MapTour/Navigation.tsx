import React, { useCallback } from 'react';

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
        <button type="button" onClick={handleNext} disabled={isLastStep}>
          Next
        </button>
      )}
      {!isLastStep && (
        <button type="button" className="skip-button" onClick={handleClose}>
          Skip
        </button>
      )}
      {isLastStep && (
        <button type="button" className="skip-button" onClick={handleClose}>
          Close
        </button>
      )}
    </div>
  );
};

export default MapTourNavigation;
