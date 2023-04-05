import Link from 'next/link';
import { useRouter } from 'next/router';

function LinkWithLang(props) {
  const router = useRouter();
  const { lang } = router.query;

  // Add lang parameter to href prop
  const hrefWithLang = {
    pathname: props.href.pathname || props.href,
    query: {
      ...props.href?.query,
      ...(lang ? { lang } : {}),
    },
  };

  return <Link {...props} href={hrefWithLang} />;
}

export default LinkWithLang;
