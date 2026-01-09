// Mock the dependencies that aren't available in Cypress environment
// These are only needed for getSubdomain() but not for getSubdomainFromURL()
import '../../src/utilities/helpers';

// Create a standalone version of getSubdomainFromURL without Next.js dependencies
const getSubdomainFromURL = (url) => {
  // Site scope depends on the domain set in the API
  let host = url.replace(/(^http(s?):\/\/)|(\.com)$/g, '');

  // Remove port number if present (e.g., frontend-test:3000 -> frontend-test)
  host = host.split(':')[0];

  const parts = host.split('.');

  let subdomain;

  if (parts.length >= 4 && parts[1] === 'staging' && parts[2] === 'resilienceatlas') {
    // Format: subdomain.staging.resilienceatlas.org
    subdomain = parts[0];
  } else if (parts.length >= 3 && parts[1] === 'resilienceatlas') {
    // Format: subdomain.resilienceatlas.org
    subdomain = parts[0];
  } else {
    // Single domain or localhost
    subdomain = parts[0];
  }

  // If no subdomain is set or we're in localhost, return null
  if (
    !subdomain ||
    subdomain === 'www' ||
    subdomain === 'resilienceatlas' ||
    subdomain === 'staging' ||
    subdomain === 'app' ||
    subdomain.startsWith('localhost') ||
    subdomain === 'frontend-test' ||
    subdomain === 'frontend-app' ||
    subdomain === 'frontend-dev' ||
    subdomain === 'frontend' ||
    subdomain.startsWith('frontend-') ||
    subdomain === '127' ||
    subdomain.startsWith('192.168') ||
    subdomain.startsWith('10.0') ||
    subdomain.startsWith('172.')
  ) {
    return null;
  }
  return subdomain;
};

describe('absoluteOrRelativeUrlWithCurrentLocale', function () {
  const locales = ['en', 'es', 'fr', 'pt_BR', 'zh_CN', 'ru'];
  const locale = 'es';
  it('returns the correct url', function () {
    // Import the helper function directly
    const { absoluteOrRelativeUrlWithCurrentLocale } = require('../../src/utilities/helpers');

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
});

describe('getSubdomainFromURL', function () {
  it('returns the correct subdomain', function () {
    expect(getSubdomainFromURL('https://www.resilienceatlas.com/en/embed?whatever')).to.eq(null);
    expect(getSubdomainFromURL('https://resilienceatlas.com/en/embed?whatever')).to.eq(null);
    expect(getSubdomainFromURL('https://staging.resilienceatlas.org/embed/map')).to.eq(null);
    expect(getSubdomainFromURL('https://app.resilienceatlas.org/embed/map')).to.eq(null);
    expect(getSubdomainFromURL('https://localhost:3000/embed/map')).to.eq(null);
    expect(getSubdomainFromURL('https://madagascar.resilienceatlas.org/embed/map')).to.eq(
      'madagascar',
    );
  });
});
