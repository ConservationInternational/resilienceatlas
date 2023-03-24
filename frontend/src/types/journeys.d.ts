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
