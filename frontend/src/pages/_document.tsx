import Document, { Html, Head, Main, NextScript } from 'next/document';
import type { DocumentContext, DocumentInitialProps } from 'next/document';

class MyDocument extends Document {
  static async getInitialProps(ctx: DocumentContext): Promise<DocumentInitialProps> {
    const initialProps = await Document.getInitialProps(ctx);
    return { ...initialProps };
  }

  render(): JSX.Element {
    return (
      <Html lang="en">
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
