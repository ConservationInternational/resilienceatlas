import axios from 'axios';
import { scopeDataUrl } from '../../../utilities/scopeDataUrl';

const headers = {
  'Content-Type': 'application/json',
};

export const get = (url, options = {}) =>
  axios.get(scopeDataUrl(url), {
    headers,
    ...options,
  });

export const post = (url, body) => axios.post(scopeDataUrl(url), body, { headers });

export default { get, post };
