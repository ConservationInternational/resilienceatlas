import React, { useRef, useCallback, useState } from 'react';

import { clickable } from 'utilities';

const CopyToClipboard = ({ value }) => {
  const input = useRef();
  const [copied, setCopied] = useState(false);

  const onCopy = useCallback(() => {
    input.current.select();
    document.execCommand('copy');
    setCopied(true);
  }, [input]);

  return (
    <div className="link-box">
      <input className="url" readOnly value={value} ref={input} />
      <div className="btn-copy" {...clickable(onCopy)}>
        {copied ? 'Copied' : 'Copy'}
      </div>
    </div>
  );
};

export default CopyToClipboard;
