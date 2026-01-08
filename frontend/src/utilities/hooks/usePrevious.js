import { useRef, useEffect } from 'react';

export const usePrevious = (value, { initial } = {}) => {
  const prev = useRef(initial ? value : null);

  useEffect(() => {
    prev.current = value;
  }, [value]);

  return prev.current;
};
