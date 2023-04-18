import React, { useMemo, useCallback } from 'react';
import { download } from 'utilities';
import { T } from '@transifex/react';

const DownloadCsv = ({ name, data }) => {
  const csvContent = useMemo(() => {
    const columns = Object.keys(data.fields).join(',');
    const rows = data.rows.map((item) => Object.values(item).join(',')).join('\n');

    return `${columns}\n${rows}`;
  }, [data]);

  const downloadFile = useCallback(() => {
    download(csvContent, `${name}.csv`, 'text/csv;charset=utf-8;');
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [csvContent]);

  return (
    <button
      type="button"
      className="btn-analysis btn-analysis-download"
      title={<T _str="Download in csv format" />}
      onClick={downloadFile}
    >
      <svg className="icon icon-downloads">
        <use xlinkHref="#icon-downloads" />
      </svg>
    </button>
  );
};

export default DownloadCsv;
