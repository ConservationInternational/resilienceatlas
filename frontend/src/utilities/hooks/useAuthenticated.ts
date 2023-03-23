import { useStore } from 'react-redux';

import { isAuthenticated } from 'utilities/authenticated';

export const useAuthenticated = (): boolean => {
  const store = useStore();
  const { user } = store.getState();
  return !!isAuthenticated(user);
};
