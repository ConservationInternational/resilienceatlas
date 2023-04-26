/* eslint-disable @next/next/no-img-element */
import React, { useEffect, useMemo } from 'react';
import type { About } from 'types/about';
import { useRouter } from 'next/router';
import Intro from './Intro';
import Nav from './Nav';
import { Row, Column } from 'react-foundation';
import { translations } from 'state/modules';
import CustomHtmlRenderer from 'views/components/CustomHtmlRenderer';

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
  const links = useMemo(
    () =>
      about?.sections
        ?.filter((s) => s.show_at_navigation)
        .map((s) => ({ title: s.title, slug: s.slug })),
    [about],
  );
  if (!aboutLoaded || !about) return null;
  const { intro, sections } = about;

  return (
    <div className="l-content">
      <Intro {...intro} />
      <Nav links={links} />
      <div className="wrap m-static-page">
        {sections.map((section) => {
          const { slug, title, paragraph, items, references, title_size } = section;
          const { text, image, image_credits, image_credits_url, image_position } = paragraph || {};

          const renderTextColumn = () => {
            const getColumnSize = () => {
              if (references) return 8;
              return image?.original ? 6 : 12;
            };
            const TitleComponent = title_size === 2 ? 'h2' : 'h3';
            return (
              <Column small={12} medium={getColumnSize()}>
                <TitleComponent>{title}</TitleComponent>
                {text && <CustomHtmlRenderer className="paragraph" content={text} />}
                {items &&
                  items.map((item) => (
                    <section key={`item-${item.title}`}>
                      <img
                        src={item.image?.original}
                        alt={translations['Team photo']}
                        className="team-photo"
                      />
                      <div className="team-bio">
                        <h3>{item.title}</h3>
                        {item.description && <CustomHtmlRenderer content={item.description} />}
                      </div>
                    </section>
                  ))}
                {references && (
                  <div className="references">
                    {references.map((reference) => (
                      <p key={`reference-${reference.slug}`} id={reference.slug}>
                        <CustomHtmlRenderer content={reference.text} />
                      </p>
                    ))}
                  </div>
                )}
              </Column>
            );
          };

          const renderImageColumn = () =>
            image?.original && (
              <Column small={12} medium={6}>
                <figure>
                  <img src={image?.original} alt={translations['About page image']} />
                  <figcaption className="credits">
                    <a href={image_credits_url} target="_blank" rel="noopener noreferrer">
                      {image_credits}
                    </a>
                  </figcaption>
                </figure>
              </Column>
            );

          return (
            <article id={slug} key={`section-${slug}`}>
              {image_position ? (
                <Row>
                  {image_position === 'left' ? (
                    <>
                      {renderImageColumn()}
                      {renderTextColumn()}
                    </>
                  ) : (
                    <>
                      {renderTextColumn()}
                      {renderImageColumn()}
                    </>
                  )}
                </Row>
              ) : (
                <Row>{renderTextColumn()}</Row>
              )}
            </article>
          );
        })}
      </div>
    </div>
  );
};

export default AboutSections;
