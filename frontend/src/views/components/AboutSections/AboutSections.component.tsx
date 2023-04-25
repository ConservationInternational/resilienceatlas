import React, { useEffect } from 'react';
import type { About } from 'types/about';
import { useRouter } from 'next/router';

type AboutSectionsProps = {
  about: About;
  aboutLoaded: boolean;
  aboutLoadedLocale: string;
  loadAbout: (locale: string) => void;
};

const AboutSections: React.FC<AboutSectionsProps> = ({
  about,
  aboutLoaded,
  aboutLoadedLocale,
  loadAbout,
}) => {
  const { locale } = useRouter();
  useEffect(() => {
    if (!aboutLoaded || aboutLoadedLocale !== locale) {
      loadAbout(locale);
    }
  }, [loadAbout, locale, aboutLoadedLocale, aboutLoaded]);

  if (!aboutLoaded || !about) return null;
  const { intro } = about;
  return <>{intro.title}</>;
};

export default AboutSections;
