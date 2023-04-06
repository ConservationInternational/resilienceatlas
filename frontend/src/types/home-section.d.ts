// TODO Simao Section | Update this (and verify which ones are actually optional against Swagger)

export interface SectionItem {
  id?: string;
  position?: number;
  title?: string;
  subtitle?: string;
  button_text?: string;
  button_url?: string;
  image_position?: string; // TODO Simao Section | replace with: 'cover' | 'left' | 'right';
  image_credits?: string;
  image_credits_url?: string;
  background_color?: string;
  image?: string;
}
