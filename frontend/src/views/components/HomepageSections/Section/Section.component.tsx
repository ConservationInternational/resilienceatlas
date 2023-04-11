import React from 'react';
import Link from 'next/link';
import cx from 'classnames';

import type { SectionItem } from 'types/homepage';

type SectionProps = Omit<SectionItem, 'id' | 'position'>;

const Section: React.FC<SectionProps> = ({
  title,
  subtitle,
  button_text,
  button_url,
  image,
  image_position,
  image_credits,
  image_credits_url,
  background_color,
}) => {
  return (
    <div
      className={cx('m-home-section', {
        'm-home-section--gradient': image.original && image_position === 'cover',
      })}
      style={{
        backgroundColor: background_color,
        backgroundSize: image_position === 'cover' && 'cover',
        ...(image?.original &&
          image_position === 'cover' && { backgroundImage: `url(${image.original})` }),
      }}
    >
      <div className="m-home-section__container">
        <div
          className={cx('m-home-section__content', {
            'm-home-section__content--center': image_position === 'cover',
            'm-home-section__content--left': image_position === 'right',
            'm-home-section__content--right': image_position === 'left',
          })}
        >
          <h2>{title}</h2>
          {subtitle && <p>{subtitle}</p>}
          {button_text && button_url && (
            <Link href={button_url}>
              <a className="btn btn-primary theme-color">{button_text}</a>
            </Link>
          )}
        </div>
      </div>
      {image?.original && image_position !== 'cover' && (
        <figure
          className={`m-home-section__figure m-home-section__figure--${image_position}`}
          style={{
            backgroundImage: `url(${image.original})`,
          }}
        />
      )}
      {image?.original && image_credits && image_credits_url && (
        <p
          className={cx('m-home-section__credits', {
            'm-home-section__credits--left': image_position === 'left',
            'm-home-section__credits--right': image_position !== 'left',
          })}
        >
          <a target="_blank" rel="noopener noreferrer" href={image_credits_url}>
            {image_credits}
          </a>
        </p>
      )}
    </div>
  );
};

export default Section;
