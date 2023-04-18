const { tx } = require('@transifex/native');
const STRINGS_WITHOUT_META = require('./server-side-translation-content.json');
const SERVER_SIDE_SOURCES = STRINGS_WITHOUT_META.reduce((acc, string) => {
  // If we need meta, comments, ... we should add them next to the strings
  // E.g.
  // 'Contract analysis panel': {
  //   string: 'Contract analysis panel',
  //   meta: {
  //      comment: 'Contract analysis panel'
  //   }
  // }
  acc[string] = { string };
  return acc;
}, {});

const pushServerSideSources = async () => {
  tx.init({
    token: process.env.TOKEN,
    secret: process.env.SECRET,
  });
  const txJob = await tx.pushSource(SERVER_SIDE_SOURCES);
  // eslint-disable-next-line no-console
  console.info('Transifex server side strings upload', txJob);
};

pushServerSideSources();
