const Footer: React.FC = () => (
  <footer className="l-footer theme-bg-color">
    <nav className="l-footer-nav">
      <p className="privacy">
        <a
          href="http://www.conservation.org/Pages/privacy.aspx"
          target="_blank"
          rel="noopener noreferrer"
        >
          Privacy policy
        </a>
      </p>
      <p className="privacy">
        <a href="mailto:resilience@conservation.org">Contact us</a>
      </p>
      <p className="copyright">&copy; 2015 Conservation International</p>
      <p className="credits">
        A website designed by&nbsp;
        <a
          href="http://www.vizzuality.com/"
          className="vizz-logo"
          target="_blank"
          rel="noopener noreferrer"
        >
          vizzuality
        </a>
      </p>
    </nav>
  </footer>
);

export default Footer;
