const { sources, workspace } = require('coc.nvim');
const { nvim } = workspace;

const schemas = {
  postgresql: {
    column_query:  "-A -c 'select table_name,column_name from information_schema.columns order by column_name asc'",
    quote: true,
    columnParser: (columns) => {
      const list = columns.slice(1, -1);
      return list.map(item => item.split('|').map(i => i.trim()));
    }
  },
  mysql: {
    column_query: ' -e "select table_name,column_name from information_schema.columns order by column_name asc"',
    quote: false,
    columnParser: (columns) => {
      const list = columns.slice(1);
      return list.map(item => item.split('\t').map(i => i.trim()));
    }
  },
};

const cache = {};
const byBuffer = {};

const saveToCache = async (bufnr, db) => {
  if (!db) {
    return;
  }

  const parsed = await nvim.call('db#url#parse', db);
  byBuffer[bufnr] = {
    db,
    scheme: parsed.scheme,
  };

  if (cache[db]) {
    return;
  }

  cache[db] = {
    tables: [],
    columns: [],
  };

  try {
    const tables = await nvim.call('db#adapter#call', [db, 'tables', [db], []]);
    cache[db].tables = [...new Set(tables)];
    if (schemas[parsed.scheme]) {
      let baseQuery = await nvim.call('db#adapter#dispatch', [db, 'interactive']);
      const columns = await nvim.call('systemlist', [`${baseQuery} ${schemas[parsed.scheme].column_query}`]);
      cache[db].columns = schemas[parsed.scheme].columnParser(columns);
    }
  } catch (err) {
    console.debug('COC DB ERROR', err);
  }
}

const fetchTablesAndColumns = async (bufnr) => {
  const dbuiDbKeyName = await nvim.call('getbufvar', [bufnr, 'dbui_db_key_name']);

  if (dbuiDbKeyName) {
    const db = await nvim.call('db_ui#get_conn_url', [dbuiDbKeyName]);
    return saveToCache(bufnr, db);
  }

  let db = await nvim.call('getbufvar', [bufnr, 'db']);
  if (!db) {
    db = await nvim.getVar('db');
  }

  return saveToCache(bufnr, db);
};

const quote = (bufnr, item, charBefore) => {
  const buf = byBuffer[bufnr];
  if (!buf || !schemas[buf.scheme] || !schemas[buf.scheme].quote) {
    return item;
  }

  if (/[A-Z]/.test(item)) {
    return `${charBefore !== '"' ? '"' : ''}${item}"`;
  }

  return item;
};


const basicFilter = (input, item, items, menu, info, bufnr, charBefore, isTriggerCharacter) => {
  if (isTriggerCharacter || input[0].toLowerCase() === item[0].toLowerCase()) {
    items.push({
      menu,
      info,
      word: quote(bufnr, item, charBefore),
      abbr: item,
    });
  }
}

const setupItemFilter = (items, bufnr, charBefore, menu, isTriggerCharacter) => (input, item, info, table) => {
  if (info === 'table') {
    return basicFilter(input, item, items, menu, info, bufnr, charBefore, isTriggerCharacter);
  }

  if (!table || item[0] === table) {
    return basicFilter(input, item[1], items, menu, item[0], bufnr, charBefore, isTriggerCharacter);
  }
};

exports.activate = context => {
  workspace.onDidOpenTextDocument(e => {
    const doc = workspace.getDocument(e.uri);
    if (doc.filetype === 'sql') {
      return fetchTablesAndColumns(doc.bufnr);
    }
  })

  const source = {
    name: 'db',
    doComplete: async function (opt) {
      const { input, triggerCharacter, line, col, bufnr } = opt;
      const isTriggerCharacter = this.getConfig('triggerCharacters').includes(triggerCharacter);
      if (!input.length && !isTriggerCharacter) return null;
      const charBefore = line.charAt(col - 1);
      const items = [];
      let table = null;
      const table_match = line.match(/"?(\w+)"?\."?\w*"?$/);
      if (Array.isArray(table_match) && table_match.length >= 1) {
        table = table_match[1];
      }
      const itemFilter = setupItemFilter(items, bufnr, charBefore, this.menu, isTriggerCharacter);

      Object.keys(cache).map((key) => {
        if (!table) {
          cache[key].tables.map(table => itemFilter(input, table, 'table'));
        }
        cache[key].columns.map(column => itemFilter(input, column, 'column', table));
      });

      return { items };
    },
  };

  context.subscriptions.push(sources.createSource(source));
}
