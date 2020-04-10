const query = 'select table_name,column_name from information_schema.columns order by column_name asc';
const postgres = {
  column_query: `-A -c '${query}'`,
  quote: true,
  columnParser: (columns) => {
    const list = columns.slice(1, -1);
    return list.map(item => item.split('|').map(i => i.trim()));
  }
};

module.exports = {
  postgresql: postgres,
  postgres,
  mysql: {
    column_query: `-e '${query}'`,
    quote: false,
    columnParser: (columns) => {
      const list = columns.slice(1);
      return list.map(item => item.split('\t').map(i => i.trim()));
    }
  },
  sqlserver: {
    column_query: `-h-1 -W -Q '${query}'`,
    quote: false,
    columnParser: (columns) => {
      const list = columns.slice(0, -2);
      return list.map(item => item.split(' ').map(i => i.trim()));
    },
  }
};
