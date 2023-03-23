import { legacy_createStore as createStore, applyMiddleware, combineReducers } from 'redux';
import { HYDRATE, createWrapper } from 'next-redux-wrapper';
import thunkMiddleware from 'redux-thunk';
import { composeWithDevTools } from 'redux-devtools-extension/developmentOnly';
import * as reducers from './modules';
import normalizerMiddleware from './middleware/normalizerMiddleware';

const composeEnhancer = composeWithDevTools({});
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
  createStore(reducer, composeEnhancer(applyMiddleware(thunkMiddleware, normalizerMiddleware)));

export default initStore;

export const wrapper = createWrapper(initStore);
