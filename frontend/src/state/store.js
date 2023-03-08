import { createStore, applyMiddleware, combineReducers } from 'redux';
import thunkMiddleware from 'redux-thunk';
import { composeWithDevTools } from 'redux-devtools-extension/developmentOnly';
import * as reducers from './modules';
import normalizerMiddleware from './middleware/normalizerMiddleware';

const composeEnhancer = composeWithDevTools({});

const initStore = createStore(
  combineReducers(reducers),
  composeEnhancer(applyMiddleware(thunkMiddleware, normalizerMiddleware)),
);

export default initStore;
