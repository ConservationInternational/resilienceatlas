const replaceDateTokens = (value, params) => {
  if (typeof value !== 'string') return value;

  return Object.entries(params).reduce((result, [key, replacement]) => {
    const token = new RegExp(`{{${key}}}|{${key}}`, 'g');
    return result.replace(token, String(replacement));
  }, value);
};

export const replaceTimelineLayerUrls = (layerConfig, params) => {
  const body = layerConfig?.body;
  if (!body) return layerConfig;

  return {
    ...layerConfig,
    body: {
      ...body,
      url: replaceDateTokens(body.url, params),
      public_tile_url: replaceDateTokens(body.public_tile_url, params),
      source: replaceDateTokens(body.source, params),
      sources: Array.isArray(body.sources)
        ? body.sources.map((source) => replaceDateTokens(source, params))
        : body.sources,
    },
  };
};
