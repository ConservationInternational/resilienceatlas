import { useEffect, useState, useCallback, useRef } from 'react';
import cx from 'classnames';
import { usePrevious } from './usePrevious';
import { useRouterParams } from 'utilities/routeParams';

export const useToggle = (initial = false): [boolean, () => void] => {
  const [toggled, setToggle] = useState(initial);

  const toggle = useCallback(() => {
    setToggle(!toggled);
  }, [toggled]);

  return [toggled, toggle];
};

export const useInput = (name, initialValue) => {
  const [value, setValue] = useState(initialValue);
  const onChange = (e) => setValue(e.target.value);
  // onInput is needed for range sliders to update in real-time while dragging
  const onInput = (e) => setValue(e.target.value);

  useEffect(() => setValue(initialValue), [initialValue]);

  const input = { name, value, onChange, onInput, setValue };

  Object.defineProperty(input, 'setValue', { enumerable: false });

  return input;
};

/**
 * @param  {string} name
 * @param  {any} initialValue
 * @param  {function} updater function to be called on blur/enter key pressed
 */
export const useUpdaterInput = (name, initialValue, updater) => {
  // setting up a input
  const [value, setValue] = useState(initialValue);
  const onChange = (e) => setValue(e.target.value);

  // call update handler only if value changed
  const update = useCallback(() => {
    if (value !== initialValue) updater(value);
  }, [value, initialValue, updater]);

  // adding a update handlers
  const onKeyPress = useCallback(
    (e) => (e.keyCode === 13 || e.charCode === 13) && update(),
    [update],
  );
  const onBlur = useCallback(() => update(), [update]);

  // update current value if initial has been changed
  useEffect(() => {
    setValue(initialValue);
  }, [initialValue]);

  return { name, value, onChange, onKeyPress, onBlur };
};

export const useDebounce = (effect, delay, deps) => {
  // Store the effect in a ref so we always call the latest version
  // without needing it in the dependency array
  const effectRef = useRef(effect);
  effectRef.current = effect;

  useEffect(() => {
    const timeout = setTimeout(() => effectRef.current(), delay);
    return () => clearTimeout(timeout);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [delay, ...deps]);
};

export const useRouterValue = (
  name: string,
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  value: any,
  { onlyOnChange = false }: { onlyOnChange?: boolean } = {},
) => {
  const { setParam } = useRouterParams();
  const prevValue = usePrevious(value, { initial: true });

  useEffect(() => {
    if (!onlyOnChange || prevValue !== value) {
      setParam(name, value);
    }
  }, [value, onlyOnChange, prevValue, name, setParam]);
};

export const useTogglerButton = (current, setter, { activeClassName = 'is-active' } = {}) => {
  const getTogglerProps = (value) => {
    const onClick = () => setter(value);

    return {
      onClick,
      className: cx({ [activeClassName]: current === value }),
    };
  };

  return {
    getTogglerProps,
  };
};
