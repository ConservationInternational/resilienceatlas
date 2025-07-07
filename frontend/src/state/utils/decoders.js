/* eslint-disable no-plusplus */
const bands = 4;

export const birds = (data, w, h, z, params) => {
  'use asm';

  const { chartLimit = 100 } = params;
  const imgData = data;

  for (let i = 0; i < w; ++i) {
    for (let j = 0; j < h; ++j) {
      const pixelPos = (j * w + i) * bands;
      const d = imgData[pixelPos];

      if (d >= 1 && d <= chartLimit + 1) {
        imgData[pixelPos] = 106;
        imgData[pixelPos + 1] = 196;
        imgData[pixelPos + 2] = 220;
        imgData[pixelPos + 3] = 255;
      } else {
        imgData[pixelPos + 3] = 0;
      }
    }
  }
};

const decoders = { birds };
export default decoders;
