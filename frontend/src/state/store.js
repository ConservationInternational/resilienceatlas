import { createStore, applyMiddleware, combineReducers } from 'redux';
import thunkMiddleware from 'redux-thunk';
import { composeWithDevTools } from 'redux-devtools-extension/developmentOnly';
import * as reducers from './modules';
import normalizrMiddleware from './middlewares/normalizrMiddleware';

const composeEnhancer = composeWithDevTools({});

export default createStore(
  combineReducers(reducers),
  composeEnhancer(applyMiddleware(thunkMiddleware, normalizrMiddleware)),
);
