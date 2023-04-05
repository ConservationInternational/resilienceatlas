import axios from 'axios';

import type { AxiosResponse } from 'axios';
import type { GetServerSideProps } from 'next';
import type { SharedURLData } from 'types/shared-url';

const SharePage: React.FC = () => null;

export const getServerSideProps: GetServerSideProps = async (ctx) => {
  const data = await axios({
    method: 'GET',
    url: `${process.env.NEXT_PUBLIC_API_HOST}/api/share/${ctx.query.id}`,
  }).then((res: AxiosResponse<{ data: SharedURLData }>) => res.data?.data);
  const redirectURL = data?.attributes.body;

  if (data) {
    return {
      redirect: {
        destination: redirectURL,
        permanent: false,
      },
    };
  }

  return {
    props: {},
  };
};

export default SharePage;
