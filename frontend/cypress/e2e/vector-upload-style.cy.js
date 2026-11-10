import {
  buildVectorTileStyle,
  pathOptionsToStyle,
} from '../../src/lib/layer-manager/plugins/plugin-openlayers/style-converter';

describe('Uploaded vector layer styles', () => {
  it('renders point symbols when the upload configuration includes a radius', () => {
    const style = pathOptionsToStyle({ radius: 5, fillColor: '#3388ff', weight: 2 });
    expect(style.getImage().getRadius()).to.equal(5);
    expect(style.getFill()).not.to.equal(null);
  });

  it('keeps existing polygon styles unchanged when no radius was supplied', () => {
    const style = pathOptionsToStyle({ fillColor: '#3388ff', weight: 2 });
    expect(style.getImage()).to.equal(null);
    expect(style.getStroke().getWidth()).to.equal(2);
  });

  it('matches the immutable table name carried in MVT features', () => {
    const styleFor = buildVectorTileStyle({
      imported_42_version: { radius: 5, fillColor: '#3388ff' },
    });
    const feature = {
      get: () => 'imported_42_version',
      getProperties: () => ({ name: 'Uploaded point' }),
    };
    expect(styleFor(feature).getImage().getRadius()).to.equal(5);
  });
});
