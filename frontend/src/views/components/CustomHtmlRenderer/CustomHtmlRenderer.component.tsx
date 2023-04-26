import React from 'react';
import type { Element } from 'html-react-parser';
import parse, { domToReact } from 'html-react-parser';

const CustomHtmlRenderer = ({ content, className }: { content: string; className?: string }) => {
  const options = {
    replace: (domNode: Element) => {
      if (domNode.name === 'a') {
        const { attribs, children } = domNode;
        return (
          <a href={attribs.href} target="_blank" rel="noopener noreferrer">
            {domToReact(children)}
          </a>
        );
      }
    },
  };

  return <div className={className}>{parse(content, options)}</div>;
};

export default CustomHtmlRenderer;
