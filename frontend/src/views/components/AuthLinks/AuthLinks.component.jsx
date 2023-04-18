import { Link } from 'next/router';
import { T } from '@transifex/react';

const AuthLinks = ({ router }) => (
  <>
    {!router.pathname.match('login') && (
      <Link href="/login">
        <a>
          <T _str="Log in" />
        </a>
      </Link>
    )}
    {!router.pathname.match('register') && (
      <Link href="/register">
        <a>
          <T _str="Sign up" />
        </a>
      </Link>
    )}
  </>
);

export default AuthLinks;
