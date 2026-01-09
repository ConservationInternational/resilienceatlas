import Link from 'next/link';
import { T } from '@transifex/react';

const AuthLinks = ({ router }) => (
  <>
    {!router.pathname.match('login') && (
      <Link href="/login">
        <T _str="Log in" />
      </Link>
    )}
    {!router.pathname.match('register') && (
      <Link href="/register">
        <T _str="Sign up" />
      </Link>
    )}
  </>
);

export default AuthLinks;
