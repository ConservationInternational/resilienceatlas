import axios, { CancelToken } from 'axios';
import { get } from '../lib/request';

// Symbol to indicate a canceled request
export const CANCELED = Symbol('CANCELED');

export const fetchData = (layerModel) => {
  const { layerConfig, layerRequest } = layerModel;
  const { url } = layerConfig.body;

  if (layerRequest) {
    layerRequest.cancel('Operation canceled by the user.');
  }

  const layerRequestSource = CancelToken.source();
  layerModel.set('layerRequest', layerRequestSource);

  const newLayerRequest = get(url, { cancelToken: layerRequestSource.token })
    .then((res) => {
      if (res.status > 400) {
        console.error(res);
        return false;
      }

      return res.data;
    })
    .catch((err) => {
      // Silently handle canceled requests - return CANCELED symbol instead of rejecting
      if (axios.isCancel(err)) {
        return CANCELED;
      }
      throw err;
    });

  return newLayerRequest;
};

export default { fetchData };
