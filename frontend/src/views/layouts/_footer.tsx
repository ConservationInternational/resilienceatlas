import { T } from '@transifex/react';

const Footer: React.FC = () => (
  <footer className="l-footer theme-bg-color">
    <nav className="l-footer-nav">
      <p className="privacy">
        <a
          href="http://www.conservation.org/Pages/privacy.aspx"
          target="_blank"
          rel="noopener noreferrer"
        >
          <T _str="Privacy policy" />
        </a>
      </p>
      <p className="privacy">
        <a
          href="https://www.conservation.org/policies/terms-of-use"
          target="_blank"
          rel="noopener noreferrer"
        >
          <T _str="Terms of Use" />
        </a>
      </p>
      <p className="privacy">
        <a href="mailto:resilience@conservation.org">
          <T _str="Contact us" />
        </a>
      </p>
      <p className="copyright">
        &copy; {new Date().getFullYear()} <T _str="Conservation International" />
      </p>
    </nav>
  </footer>
);

export default Footer;
