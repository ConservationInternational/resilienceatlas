export const isAuthenticated = (user): boolean => {
  return !!user.auth_token;
};
