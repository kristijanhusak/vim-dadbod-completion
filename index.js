const { sources, workspace } = require('coc.nvim');
const { nvim } = workspace;

const schemas = {
  postgresql: {
    column_query:  "-A -c 'select column_name from information_schema.columns group by column_name order by column_name asc'",
    quote: true,
    filterColumns: columns => columns.slice(1, -1),
  },
  mysql: {
    column_query: ' -e "select column_name from information_schema.columns"',
    quote: false,
    filterColumns: columns => columns.slice(1),
  },
};

const cache = {};
const byBuffer = {};

const saveToCache = async (bufnr, db) => {
  if (!db) {
    return;
  }

  const parsed = await nvim.call('db#url#parse', db)
  byBuffer[bufnr] = {
    db,
    scheme: parsed.scheme,
  };

  if (cache[db]) {
    return;
  }

  cache[db] = {
    tables: [],
    columns: []
  };

  try {
    const tables = await nvim.call('db#adapter#call', [db, 'tables', [db], []])
    cache[db].tables = [...new Set(tables)];
    if (schemas[parsed.scheme]) {
      let baseQuery = await nvim.call('db#adapter#dispatch', [db, 'interactive'])
      const columns = await nvim.call('systemlist', [`${baseQuery} ${schemas[parsed.scheme].column_query}`])
      cache[db].columns = schemas[parsed.scheme].filterColumns(columns);
    }
  } catch (e) {
    console.debug('ERROR IN COC DB', e)
  }
}

const fetchTablesAndColumns = async (bufnr) => {
  const dbuiDbKeyName = await nvim.call('getbufvar', [bufnr, 'dbui_db_key_name'])

  if (dbuiDbKeyName) {
    const db = await nvim.call('db_ui#get_conn_url', [dbuiDbKeyName]);
    return saveToCache(bufnr, db)
  }

  let db = await nvim.call('getbufvar', [bufnr, 'db'])
  if (!db) {
    db = await nvim.getVar('db')
  }

  return saveToCache(bufnr, db);
};

const quote = (bufnr, item, charBefore) => {
  const buf = byBuffer[bufnr]
  if (!buf || !schemas[buf.scheme] || !schemas[buf.scheme].quote) {
    return item;
  }

  if (/[A-Z]/.test(item)) {
    return `${charBefore !== '"' ? '"' : ''}${item}"`
  }

  return item;
};

const setupItemFilter = (items, bufnr, charBefore, menu) => (input, item, info) => {
  if (input[0].toLowerCase() === item[0].toLowerCase()) {
    items.push({
      menu,
      info,
      word: quote(bufnr, item, charBefore),
      abbr: item,
    });
  }
};

exports.activate = context => {
  workspace.onDidOpenTextDocument(e => {
    const doc = workspace.getDocument(e.uri)
    if (doc.filetype === 'sql') {
      return fetchTablesAndColumns(doc.bufnr)
    }
  })

  const source = {
    name: 'db',
    filetypes: ['sql'],
    doComplete: async function (opt) {
      const { input } = opt;
      if (!input.length) return null;
      const charBefore = opt.line.charAt(opt.col - 1);
      const items = []
      const itemFilter = setupItemFilter(items, opt.bufnr, charBefore, this.menu)

      Object.keys(cache).map((key) => {
        cache[key].tables.map(table => itemFilter(input, table, 'table'));
        cache[key].columns.map(column => itemFilter(input, column, 'column'));
      });

      return { items };
    },
  };

  context.subscriptions.push(sources.createSource(source));
}
