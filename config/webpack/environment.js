const { environment } = require('@rails/webpacker')

const myCssLoaderOptions = {
  modules: {
    localIdentName: '[name]__[local]___[hash:base64:10]',
  },
  sourceMap: true,
}
const CSSLoader = environment.loaders
  .get('moduleSass')
  .use.find((el) => el.loader === 'css-loader')

CSSLoader.options = { ...CSSLoader.options, ...myCssLoaderOptions }

module.exports = environment
