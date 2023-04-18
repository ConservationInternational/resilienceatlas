export type TProps = {
  _str: string;
  _comment?: string;
  [key: string]: unknown;
};
export type TypedT = JSX.Element<TProps>;

export type Translations = {
  [key: string]: string;
};
