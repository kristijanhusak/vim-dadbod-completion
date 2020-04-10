const { sources, workspace } = require('coc.nvim');
const schemas = require('./schemas')
const { debounce } = require('./utils');
const aliasParser = require('./alias_parser');
const { nvim } = workspace;

const cache = {};
const buffers = {};

const cacheTableAliases = async (bufnr) => {
  const content = await nvim.call('getbufline', [bufnr, 1, '$'])
  try {
    const aliases = aliasParser(content.join(' ').trim(), cache[buffers[bufnr].db].tables);
    buffers[bufnr].table_aliases = aliases;
  } catch (err) {
    console.debug('Failed to parse sql: ', err);
  }
};

const saveToCache = async (bufnr, db, table = null) => {
  if (!db) {
    return;
  }

  const parsed = await nvim.call('db#url#parse', db);
  buffers[bufnr] = buffers[bufnr] || {};
  buffers[bufnr].table = table;
  buffers[bufnr].db = db;
  buffers[bufnr].scheme = parsed.scheme;
  buffers[bufnr].table_aliases = buffers[bufnr].table_aliases || {};

  if (cache[db]) {
    return;
  }

  cache[db] = { tables: [], columns: [] };

  try {
    const postgresAdapter = await nvim.getVar('db_adapter_postgres')
    const sqliteAdapter = await nvim.getVar('db_adapter_sqlite3')
    if (!postgresAdapter) {
      await nvim.command('let g:db_adapter_postgres = "db#adapter#postgresql#"')
    }
    if (!sqliteAdapter) {
      await nvim.command('let g:db_adapter_sqlite3 = "db#adapter#sqlite#"')
    }
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
  const dbuiDbTableName = await nvim.call('getbufvar', [bufnr, 'dbui_table_name']);

  if (dbuiDbKeyName) {
    const db = await nvim.call('db_ui#get_conn_url', [dbuiDbKeyName]);
    return saveToCache(bufnr, db, dbuiDbTableName);
  }

  let db = await nvim.call('getbufvar', [bufnr, 'db']);
  if (!db) {
    db = await nvim.getVar('db');
  }
  const table = await nvim.call('getbufvar', [bufnr, 'db_table'])

  return saveToCache(bufnr, db, table);
};

const quote = (bufnr, item, charBefore) => {
  const buf = buffers[bufnr];
  if (!buf || !schemas[buf.scheme] || !schemas[buf.scheme].quote) {
    return item;
  }

  if (/[A-Z]/.test(item)) {
    return `${charBefore !== '"' ? '"' : ''}${item}"`;
  }

  return item;
};

const setupMatcher = (input, isTriggerCharacter) => item => isTriggerCharacter || input[0].toLowerCase() === item[0].toLowerCase();


const setupFilter = (items, opt, menu, isTriggerCharacter) => {
  const { input, line, col, bufnr } = opt;
  const charBefore = line.charAt(col - 1);
  const bufTable = buffers[bufnr] && buffers[bufnr].table
  const completeItem = (word, info) => ({
    menu,
    info,
    word: quote(bufnr, word, charBefore),
    abbr: word,
  })

  const isMatch = setupMatcher(input, isTriggerCharacter);
  return (item, type, table) => {
    if (type === 'table') {
      if (isMatch(item)) {
        items.push(completeItem(item, type));
      }
      return;
    }

    const alias = buffers[bufnr].table_aliases[item[0]];
    if (table) {
      if ((item[0] === table || (alias && alias === table)) && isMatch(item[1])) {
        items.push(completeItem(item[1], table));
      }
      return;
    }

    if (bufTable) {
      if ((item[0] === bufTable || (alias && alias === bufTable)) && isMatch(item[1])) {
        items.push(completeItem(item[1], bufTable));
      }
      return;
    }

    if (isMatch(item[1])) {
      items.push(completeItem(item[1], bufTable));
    }
  }
};

const cacheAliases = debounce(cacheTableAliases, 50);

exports.activate = context => {
  workspace.onDidOpenTextDocument(e => {
    const doc = workspace.getDocument(e.uri);
    if (doc.filetype === 'sql') {
      return fetchTablesAndColumns(doc.bufnr);
    }
  });

  workspace.onDidChangeTextDocument(async _e => {
    const doc = await workspace.document;
    return cacheAliases(doc.bufnr);
  });


  const source = {
    name: 'db',
    doComplete: async function (opt) {
      const { input, triggerCharacter, line } = opt;
      const isTriggerCharacter = this.getConfig('triggerCharacters').includes(triggerCharacter);
      if (!input.length && !isTriggerCharacter) return null;
      cacheTableAliases(opt.bufnr);
      const items = [];
      let table = null;
      const table_match = line.match(/"?(\w+)"?\."?\w*"?$/);
      if (Array.isArray(table_match) && table_match.length >= 1) {
        table = table_match[1];
      }
      const itemFilter = setupFilter(items, opt, this.menu, isTriggerCharacter)

      Object.keys(cache).map((key) => {
        if (!table) {
          cache[key].tables.map(table => itemFilter(table, 'table'));
        }
        cache[key].columns.map(column => itemFilter(column, 'column', table));
      });

      return { items };
    },
  };

  context.subscriptions.push(sources.createSource(source));
}
