import { useCallback, useEffect } from 'react';

type Listener<State> = (state: State) => void;

export const useSyncedState = (function () {
  let _state = null;
  const _listeners = [];

  /**
   * Synchronize state between several components
   * @param initialState Initial synced state
   * @param callback Callback executed when the synced state has changed
   * @returns Callback to modify the synced state
   */
  return <State>(initialState: State, callback: Listener<State>) => {
    const addListener = useCallback((listener: Listener<State>) => {
      _listeners.push(listener);
    }, []);

    const removeListener = useCallback((listener: Listener<State>) => {
      const index = _listeners.findIndex((l) => l === listener);
      if (index !== null) {
        _listeners.splice(index, 1);
      }
    }, []);

    const broadcastState = useCallback(() => {
      _listeners.forEach((listener) => listener(_state));
    }, []);

    const updateState = useCallback(
      (newState: State) => {
        _state = newState;
        broadcastState();
      },
      [broadcastState],
    );

    useEffect(() => {
      addListener(callback);

      if (_state === null) {
        _state = initialState;
        broadcastState();
      }

      return () => removeListener(callback);
    }, [initialState, callback, addListener, removeListener, broadcastState]);

    return updateState;
  };
})();
