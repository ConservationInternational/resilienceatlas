import { useRouter } from 'next/router';

export const useGetParams = (param: string): string => {
  const router = useRouter();
  const { query } = router;
  return query[param] as string;
};
