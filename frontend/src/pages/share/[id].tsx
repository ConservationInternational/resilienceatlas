import axios from 'axios';

import type { GetServerSideProps } from 'next';
import type { SharedURLData } from 'types/shared-url';

const SharePage: React.FC = () => null;

export const getServerSideProps: GetServerSideProps = async (ctx) => {
  try {
    const { data } = await axios.get<{ data: SharedURLData }>(
      `${process.env.NEXT_PUBLIC_API_HOST}/api/share/${ctx.query.id}`,
    );

    if (data) {
      const destination = data.data?.attributes?.body;
      return {
        redirect: {
          destination,
          permanent: false,
        },
      };
    }
  } catch (error) {
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
