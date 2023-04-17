import Document, { Html, Head, Main, NextScript } from 'next/document';
import type { DocumentContext, DocumentInitialProps } from 'next/document';
import localesJson from 'locales.config.json';

type Locale = {
  locale: string;
  default: boolean;
  name: string;
};

class MyDocument extends Document {
  static async getInitialProps(ctx: DocumentContext): Promise<DocumentInitialProps> {
    const initialProps = await Document.getInitialProps(ctx);
    return { ...initialProps };
  }
  render(): JSX.Element {
    const defaultLocale = localesJson.locales.find((l: Locale) => l.default).locale;
    return (
      <Html lang={defaultLocale}>
        <Head />
        <body>
          <div id="root">
            <Main />
          </div>
          <NextScript />
        </body>
      </Html>
    );
  }
}

export default MyDocument;
