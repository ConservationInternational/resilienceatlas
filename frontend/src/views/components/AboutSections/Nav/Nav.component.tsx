import { Row, Column } from 'react-foundation';
import type { Translations } from 'types/transifex';

type NavProps = {
  links: {
    title: string;
    slug: string;
  }[];
  translations: Translations;
};

const Nav: React.FC<NavProps> = ({ links, translations }) => {
  return (
    <nav className="l-section-nav">
      <Row>
        <Column small={12} medium={12}>
          <ul className="m-section-nav">
            {links.map((link) => (
              <li key={`nav-${link.slug}`}>
                <a href={`#${link.slug}`} title={translations['About section link']}>
                  {link.title}
                </a>
              </li>
            ))}
          </ul>
        </Column>
      </Row>
    </nav>
  );
};

export default Nav;
