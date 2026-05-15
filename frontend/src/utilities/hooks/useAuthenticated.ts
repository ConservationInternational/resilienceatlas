import { useSelector } from 'react-redux';

import { isAuthenticated } from 'utilities/authenticated';

export const useAuthenticated = (): boolean => {
  const user = useSelector((state: { user: unknown }) => state.user);
  return !!isAuthenticated(user);
};
