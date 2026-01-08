import { useCallback, useState } from 'react';

export const useDownloadableReport = () => {
  const [href, setHref] = useState('');

  const onClick = useCallback(() => {
    const { search } = window.location;
    const reportUrl = `${process.env.NEXT_PUBLIC_API_HOST}/report${search}`;
    const webshotUrl = 'https://www.resilienceatlas.org/webshot';

    setHref(
      `${webshotUrl}?filename=analysis-report&mediatype=screen&backgrounds=true&url=${encodeURIComponent(
        reportUrl,
      )}`,
    );
  }, []);

  return {
    download: 'true',
    href,
    onClick,
  };
};
