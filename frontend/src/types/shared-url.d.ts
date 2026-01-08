export type SharedURLPayload = {
  uid: string;
};

export type SharedURLData = {
  id: string;
  type: 'shared_urls';
  attributes: {
    uid: string;
    body: string;
  };
};
