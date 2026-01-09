import {
  legacy_createStore as createStore,
  applyMiddleware,
  combineReducers,
  compose,
} from 'redux';
import { HYDRATE, createWrapper } from 'next-redux-wrapper';
import { thunk } from 'redux-thunk';
import * as reducers from './modules';
import normalizerMiddleware from './middleware/normalizerMiddleware';
import siteScopeAuthMiddleware from './middleware/siteScopeAuthMiddleware';
import siteLoadMiddleware from './middleware/siteLoadMiddleware';

// Use Redux DevTools extension if available (development only)
const composeEnhancer =
  typeof window !== 'undefined' && window.__REDUX_DEVTOOLS_EXTENSION_COMPOSE__
    ? window.__REDUX_DEVTOOLS_EXTENSION_COMPOSE__({})
    : compose;

const combinedReducer = combineReducers(reducers);

const reducer = (state, action) => {
  if (action.type === HYDRATE) {
    const nextState = {
      ...state, // use previous state
      ...action.payload, // apply delta from hydration
    };
    return nextState;
  } else {
    return combinedReducer(state, action);
  }
};

const initStore = () =>
  createStore(
    reducer,
    composeEnhancer(
      applyMiddleware(thunk, normalizerMiddleware, siteScopeAuthMiddleware, siteLoadMiddleware),
    ),
  );

export default initStore;

export const wrapper = createWrapper(initStore);
