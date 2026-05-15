import { Html, Head, Main, NextScript } from 'next/document';
import type { ReactElement } from 'react';

export default function Document(): ReactElement {
  return (
    <Html>
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
