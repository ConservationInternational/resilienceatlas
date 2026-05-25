import React from 'react';
import type { Element } from 'html-react-parser';
import parse, { domToReact } from 'html-react-parser';

const isSafeHref = (href: string | undefined): boolean => {
  if (!href) return false;
  try {
    const url = new URL(
      href,
      typeof window !== 'undefined' ? window.location.href : 'https://example.com',
    );
    return url.protocol === 'https:' || url.protocol === 'http:' || url.protocol === 'mailto:';
  } catch {
    return false;
  }
};

const CustomHtmlRenderer = ({
  content,
  className,
  dataTest,
}: {
  content: string;
  className?: string;
  dataTest?: string;
}) => {
  const options = {
    replace: (domNode: Element) => {
      if (domNode.name === 'a') {
        const { attribs, children } = domNode;
        const safeHref = isSafeHref(attribs.href) ? attribs.href : '#';
        return (
          <a href={safeHref} target="_blank" rel="noopener noreferrer">
            {domToReact(children as Parameters<typeof domToReact>[0])}
          </a>
        );
      }
    },
  };

  return (
    <div className={className} data-test={dataTest}>
      {parse(content, options)}
    </div>
  );
};

export default CustomHtmlRenderer;
