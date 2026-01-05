import { Row, Column } from 'views/components/Grid';

type NavProps = {
  links: {
    title: string;
    slug: string;
  }[];
};

const Nav: React.FC<NavProps> = ({ links }) => {
  return (
    <nav className="l-section-nav">
      <Row>
        <Column small={12} medium={12}>
          <ul className="m-section-nav">
            {links.map((link) => (
              <li key={`nav-${link.slug}`}>
                <a href={`#${link.slug}`} className="link">
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
