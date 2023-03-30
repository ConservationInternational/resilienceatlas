export const getTableName = () => {
  let name = "gadm28_adm0_new where not iso ='TWN'";
  const { isSubdomain } = window;

  if (isSubdomain === 'indicators') {
    name = "gadm28_adm0_new where iso in ('KEN', 'UGA', 'GHA', 'RWA', 'TZA')";
  }
  return name;
};
