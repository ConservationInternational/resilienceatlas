import { Link } from 'next/router';

const AuthLinks = ({ router }) => (
  <>
    {!router.pathname.match('login') && (
      <Link href="/login">
        <a>Log in</a>
      </Link>
    )}
    {!router.pathname.match('register') && (
      <Link href="/register">
        <a>Sign up</a>
      </Link>
    )}
  </>
);

export default AuthLinks;
