import { absoluteOrRelativeUrlWithCurrentLocale } from '../../../src/utilities/helpers';
import { parseDates } from '../../../src/state/modules/layers/utils';

describe('absoluteOrRelativeUrlWithCurrentLocale', function () {
  const locales = ['en', 'es', 'fr', 'pt_BR', 'zh_CN', 'ru'];
  const locale = 'es';
  it('returns the correct url', function () {
    expect(
      absoluteOrRelativeUrlWithCurrentLocale(
        'https://www.resilienceatlas.com/en/embed?whatever',
        locale,
        locales,
      ),
    ).to.eq('https://www.resilienceatlas.com/es/embed?whatever');

    expect(
      absoluteOrRelativeUrlWithCurrentLocale(
        'http://locahost:3000/embed?whatever',
        locale,
        locales,
      ),
    ).to.eq('http://locahost:3000/es/embed?whatever');

    expect(absoluteOrRelativeUrlWithCurrentLocale('/embed?whatever', locale, locales)).to.eq(
      '/es/embed?whatever',
    );

    expect(absoluteOrRelativeUrlWithCurrentLocale('/en/embed?whatever', locale, locales)).to.eq(
      '/es/embed?whatever',
    );
    expect(
      absoluteOrRelativeUrlWithCurrentLocale(
        'http://localhost:3000/en/map?tab=layers&layers=%center%es%22',
        locale,
        locales,
      ),
    ).to.eq('http://localhost:3000/es/map?tab=layers&layers=%center%es%22');
    expect(
      absoluteOrRelativeUrlWithCurrentLocale(
        'https://staging.resilienceatlas.org/embed/map?tab=layers&layers=...',
        locale,
        locales,
      ),
    ).to.eq('https://staging.resilienceatlas.org/es/embed/map?tab=layers&layers=...');
  });

  describe('parseDates for public and authorized COG tile routes', () => {
    it('pins the selected date in public URLs and temporal source fallbacks', () => {
      const parsed = parseDates({
        date: '2023-12-31',
        timeline: { defaultDate: new Date('2024-01-02T00:00:00Z') },
        layerConfig: {
          body: {
            public_tile_url:
              '/api/public-tiles/12/version/{z}/{x}/{y}?time={{year}}-{{month}}-{{day}}',
            source: 'https://storage.googleapis.com/data/ndvi-{{year}}-{{month}}-{{day}}.tif',
            sources: ['https://storage.googleapis.com/data/ndvi-{{year}}-{{month}}-{{day}}.tif'],
          },
        },
      });

      expect(parsed.layerConfig.body.public_tile_url).to.eq(
        '/api/public-tiles/12/version/{z}/{x}/{y}?time=2023-12-31',
      );
      expect(parsed.layerConfig.body.source).to.eq(
        'https://storage.googleapis.com/data/ndvi-2023-12-31.tif',
      );
      expect(parsed.layerConfig.body.sources[0]).to.eq(
        'https://storage.googleapis.com/data/ndvi-2023-12-31.tif',
      );
    });
  });
});
