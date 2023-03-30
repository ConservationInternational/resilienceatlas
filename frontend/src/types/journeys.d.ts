export type Journey = {
  id: number;
  title: string;
  subtitle: string;
};

export type JourneyItem = Journey & {
  theme: string;
  bg: string;
  bgBig: string;
};

export type JourneyStep = {
  number: number;
  type: string;
  title: string;
  subtitle: string;
  theme: string;
  background: string;
  credits: string;
  creditsUrl: string;
  content: string;
};

export type JourneyDetail = Journey & {
  steps: JourneyStep[];
};

export type JourneyList = JourneyItem[];
