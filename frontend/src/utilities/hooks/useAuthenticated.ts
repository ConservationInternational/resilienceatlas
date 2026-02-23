import { useSelector } from 'react-redux';

import { isAuthenticated } from 'utilities/authenticated';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const useAuthenticated = (): boolean => {
  const user = useSelector((state: { user: unknown }) => state.user);
  return !!isAuthenticated(user);
};
