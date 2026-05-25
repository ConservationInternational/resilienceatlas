import axios from 'axios';

import type { GetServerSideProps } from 'next';
import type { SharedURLData } from 'types/shared-url';

/**
 * Only allow relative paths as share destinations.
 * Absolute URLs (https://evil.com) and non-path strings are rejected.
 */
const isSafeDestination = (dest: unknown): dest is string =>
  typeof dest === 'string' && dest.startsWith('/') && !dest.startsWith('//');

const SharePage: React.FC = () => null;

export const getServerSideProps: GetServerSideProps = async (ctx) => {
  try {
    const { data } = await axios.get<{ data: SharedURLData }>(
      `${process.env.NEXT_PUBLIC_API_HOST}/api/share/${ctx.query.id}`,
    );

    if (data) {
      const destination = data.data?.attributes?.body;
      if (!isSafeDestination(destination)) {
        return { redirect: { destination: '/404', permanent: false } };
      }
      return {
        redirect: {
          destination,
          permanent: false,
        },
      };
    }
  } catch {
    return {
      redirect: {
        destination: '/404',
        permanent: false,
      },
    };
  }

  return {
    props: {},
  };
};

export default SharePage;
