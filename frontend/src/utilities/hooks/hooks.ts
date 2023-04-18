import { useEffect, useState, useCallback } from 'react';
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

  useEffect(() => setValue(initialValue), [initialValue]);

  const input = { name, value, onChange, setValue };

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
  }, [value, initialValue]);

  // adding a update handlers
  const onKeyPress = useCallback(
    (e) => (e.keyCode === 13 || e.charCode === 13) && update(),
    [value],
  );
  const onBlur = useCallback(() => update(), [value]);

  // update current value if initial has been changed
  useEffect(() => {
    setValue(initialValue);
  }, [initialValue]);

  return { name, value, onChange, onKeyPress, onBlur };
};

export const useDebounce = (effect, delay, deps) => {
  useEffect(() => {
    const timeout = setTimeout(effect, delay);

    return () => clearTimeout(timeout);
  }, deps);
};

export const useRouterValue = (
  name: string,
  value: any,
  { onlyOnChange = false }: { onlyOnChange?: boolean } = {},
) => {
  const { setParam } = useRouterParams();
  const prevValue = usePrevious(value, { initial: true });

  useEffect(() => {
    if (!onlyOnChange || prevValue !== value) {
      setParam(name, value);
    }
  }, [value]);
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
