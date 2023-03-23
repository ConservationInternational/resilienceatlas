import { getToken } from 'state/modules/user';

export const isAuthenticated = (user): boolean => {
  if (typeof window !== 'undefined') return !!getToken();
  return !!user.auth_token;
};
