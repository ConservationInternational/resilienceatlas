import { absoluteOrRelativeUrlWithCurrentLocale } from '../../../src/utilities/helpers';

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
  });
});
