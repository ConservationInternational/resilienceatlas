const ee = require('@google/earthengine');
const PRIVATE_KEY = require('./privatekey.json');


const arrSum = arr => arr.reduce((a, b) => a + b, 0);

const serialize = (originalData) => {
  const props = originalData[0].properties;
  const data = props.histogram;
  const bucketWidth = data.bucketWidth;
  const countSum = arrSum(data.histogram);

  return JSON.stringify({
    rows: data.histogram.map((d, i) => ({
      min: data.bucketMin + (bucketWidth * i),
      max: data.bucketMin + (bucketWidth * (i + 1)),
      count: d,
      percent: d / countSum
    })),
    fields: {
      min: { type: 'number' },
      max: { type: 'number' },
      count: { type: 'number' },
      percent: { type: 'number' }
    },
    total_rows: data.histogram.length,
    stats: {
       min: props.min,
      max: props.max,
      mean: props.mean,
      stdev: props.stdDev,
      sum: props.sum
    }
  });
};

const calcHistogram = (assetId, geometry) => {
  const image = ee.Image(assetId);
  const reducers = ee.Reducer.histogram(20)
      .combine(ee.Reducer.minMax(), '', true)
      .combine(ee.Reducer.mean(),'', true )
      .combine(ee.Reducer.stdDev(), '', true)
      .combine(ee.Reducer.sum(), '', true);
  const regReducer = {
    collection: ee.FeatureCollection(geometry.features),
    reducer: reducers
  };
  const histogram = image.reduceRegions(regReducer).toList(10000);

  return histogram;
};

exports.histogram = (req, res) => {
  const assetId = req.body.assetId;
  const geometry = req.body.geometry;
  
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Content-Type', 'application/json');
  

  if (req.method === 'OPTIONS') {
   // Send response to OPTIONS requests
   res.set('Access-Control-Allow-Methods', 'POST, GET, OPTIONS');
   res.set('Access-Control-Allow-Headers', 'Content-Type');
   res.set('Access-Control-Max-Age', '3600');
   res.status(204).send('');
  }

  ee.data.authenticateViaPrivateKey(
    PRIVATE_KEY,
    () => {
      ee.initialize(null, null, () => {
        const result = calcHistogram(assetId, geometry);
        result.evaluate((json) => res.status(200).send(serialize(json)));
      });
    }, 
    e => console.error(`Authentication error: ${e}`)
  );
};
