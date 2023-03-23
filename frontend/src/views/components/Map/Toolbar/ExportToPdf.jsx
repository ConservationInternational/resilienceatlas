import React, { useMemo } from 'react';

const ExportToPdf = () => {
  const downloadURL = useMemo(
    () =>
      `${
        process.env.NEXT_PUBLIC_API_HOST
      }/webshot?filename=export-map-${new Date().getTime()}.pdf&url=${window.location.href}`,
    [],
  );
  return (
    <a href={downloadURL} rel="noopener noreferrer" target="_blank" className="btn-export-to-pdf">
      <svg className="icon">
        <use xmlnsXlink="http://www.w3.org/1999/xlink" xlinkHref="#icon-downloads" />
      </svg>
    </a>
  );
};

export default ExportToPdf;
