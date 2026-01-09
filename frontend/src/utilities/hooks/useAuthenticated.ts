import { useStore } from 'react-redux';

import { isAuthenticated } from 'utilities/authenticated';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const useAuthenticated = (): boolean => {
  const store = useStore();
  const state = store.getState() as { user: unknown };
  return !!isAuthenticated(state.user);
};
