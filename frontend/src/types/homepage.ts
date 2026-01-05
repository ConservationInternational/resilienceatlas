import type { Attributes as JourneyAttributes } from 'types/journeys';

export enum SectionTypes {
  Journey = 'homepage_journeys',
  Section = 'homepage_sections',
}

export interface BackgroundImage {
  small: string;
  medium: string;
  original: string;
}

export interface Intro {
  title: string;
  subtitle?: string;
  background_image?: BackgroundImage;
  credits?: string;
  credits_url?: string;
}

export interface JourneyItem extends JourneyAttributes {
  id?: string;
  position: number;
}

export interface SectionItem {
  id?: string;
  position?: number;
  title?: string;
  subtitle?: string;
  button_text?: string;
  button_url?: string;
  image_position?: 'cover' | 'left' | 'right';
  image_credits?: string;
  image_credits_url?: string;
  background_color?: string;
  image?: BackgroundImage;
}
