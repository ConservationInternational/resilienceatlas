export type JourneyList = JourneyItem[];

export interface JourneyItem {
  id: string;
  type: string;
  attributes: Attributes;
  relationships: Relationships;
}

export interface Attributes {
  title: string;
  subtitle: string;
  theme: string;
  background_image: BackgroundImage;
  credits: string;
  credits_url: string;
  published: boolean;
}

export interface BackgroundImage {
  small: string;
  medium: string;
  original: string;
}

export interface Relationships {
  journey_steps: JourneySteps;
}

export interface JourneySteps {
  data: Datum[];
}

export interface Datum {
  id: string;
  type: Type;
}

export enum Type {
  JourneySteps = 'journey_steps',
}

export interface Journey {
  data: Data;
  included: Included[];
}

export type JourneyDetail = Journey & {
  steps: JourneySteps;
};

export interface Data {
  id: string;
  type: string;
  attributes: DataAttributes;
  relationships: Relationships;
}

export interface DataAttributes {
  title: string;
  subtitle: string;
  theme: string;
  background_image: BackgroundImage;
  credits: string;
  credits_url: string;
  published: boolean;
}

export interface Included {
  id: string;
  type: string;
  attributes: JourneyAttributes;
}

export interface JourneyAttributes {
  step_type: string;
  position: number;
  title?: string;
  description?: string;
  credits?: string;
  credits_url?: string;
  background_image?: BackgroundImage;
  subtitle?: string;
  content?: string;
  background_color?: string;
  chapter_number?: number;
  source?: string;
  mask_sql?: string;
  map_url?: string;
  embedded_map_url?: string;
}
