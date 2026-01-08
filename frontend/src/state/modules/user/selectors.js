export const getUserLoggedIn = (state) => !!state.user.auth_token;
export const getUserToken = (state) => state.user.auth_token;
export const getUserData = (state) => !!state.user.data;
