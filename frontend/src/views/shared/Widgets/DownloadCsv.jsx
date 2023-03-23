import React, { useMemo, useCallback } from 'react';
import { download } from 'utilities';

const DownloadCsv = ({ name, data }) => {
  const csvContent = useMemo(() => {
    const columns = Object.keys(data.fields).join(',');
    const rows = data.rows.map((item) => Object.values(item).join(',')).join('\n');

    return `${columns}\n${rows}`;
  }, [data]);

  const downloadFile = useCallback(() => {
    download(csvContent, `${name}.csv`, 'text/csv;charset=utf-8;');
  }, [csvContent]);

  return (
    <button
      type="button"
      className="btn-analysis btn-analysis-download"
      title="Download in csv format"
      onClick={downloadFile}
    >
      <svg className="icon icon-downloads">
        <use xlinkHref="#icon-downloads" />
      </svg>
    </button>
  );
};

export default DownloadCsv;
