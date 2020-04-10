const postgres = {
  column_query:  "-A -c 'select table_name,column_name from information_schema.columns order by column_name asc'",
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
    column_query: ' -e "select table_name,column_name from information_schema.columns order by column_name asc"',
    quote: false,
    columnParser: (columns) => {
      const list = columns.slice(1);
      return list.map(item => item.split('\t').map(i => i.trim()));
    }
  },
};
