const ee = require("@google/earthengine");
const functions = require('@google-cloud/functions-framework');
const PRIVATE_KEY = require("./privatekey.json");

const serialize = (originalData) => {
	return JSON.stringify({
		rows: [originalData],
	});
};

const interact_raster = (input) => {
	const reducer = {
		reducer: ee.Reducer.first(),
		geometry: ee.Geometry.Point(JSON.parse(input.point), "EPSG:4326"),
		bestEffort: true,
		maxPixels: 10e8,
		tileScale: 10,
	};
	return ee.Image(input.asset_id.replaceAll("'", "")).reduceRegion(reducer);
};

functions.http('rasterInteraction', (req, res) => {
	const params = req.query;

	res.set("Access-Control-Allow-Origin", "*");
	res.set("Content-Type", "application/json");

	if (req.method === "OPTIONS") {
		// Send response to OPTIONS requests
		res.set("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
		res.set("Access-Control-Allow-Headers", "Content-Type");
		res.set("Access-Control-Max-Age", "3600");
		res.status(204).send("");
	}
	ee.data.authenticateViaPrivateKey(
		PRIVATE_KEY,
		() => {
			ee.initialize(null, null, () => {
				const result = interact_raster(params);
				try {
					result.getInfo();
				} catch (error) {
					console.error(`Could not load image: ${error.toString()}`);
					// This would likely be the ideal response, but adds a BC break
					// return res.status(404).send(serialize({ error: error.message }));
					return res.status(200).send(serialize(null));
				}
				result.evaluate((json) =>
					res.status(200).send(serialize(json))
				);
			});
		},
		(e) => console.error(`Authentication error: ${e}`)
	);
});
