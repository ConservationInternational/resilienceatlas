export interface About {
  intro: AboutAttributes;
  sections: (
    | IncludedAttributes
    | {
        paragraph?: IncludedAttributes;
        items?: IncludedAttributes;
        references?: IncludedAttributes;
      }
  )[];
}

export interface RawAbout {
  data: AboutData;
  included: AboutIncluded[];
}

export enum SectionTypes {
  section = 'static_page_sections',
  paragraphs = 'static_page_section_paragraphs',
  items = 'static_page_section_items',
  references = 'static_page_section_paragraphs',
}

export interface AboutData {
  id: string;
  type: string;
  attributes: AboutAttributes;
  relationships: AboutRelationships;
}

export interface AboutAttributes {
  title: string;
  slug: string;
  image: Image;
  image_credits: string;
  image_credits_url: string;
}

export interface Image {
  small: string;
  medium: string;
  original: string;
}

export interface AboutRelationships {
  sections: AboutSections;
}

export interface AboutSections {
  data: Datum[];
}

export interface Datum {
  id: string;
  type: string;
}

export interface AboutIncluded {
  id: string;
  type: string;
  attributes: IncludedAttributes;
  relationships?: IncludedRelationships;
}

export interface IncludedAttributes {
  title?: string;
  slug?: string;
  title_size?: number;
  section_type?: string;
  show_at_navigation?: boolean;
  position?: number;
  text?: string;
  image?: Image;
  image_credits?: string;
  image_credits_url?: string;
  image_position?: string;
  description?: string;
}

export interface IncludedRelationships {
  section_paragraph: SectionParagraph;
  section_items: SectionItems;
  section_references: SectionReferences;
}

export interface SectionParagraph {
  data?: Datum;
}

export interface SectionItems {
  data: Datum[];
}

export interface SectionReferences {
  data: Datum[];
}
