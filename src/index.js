const { sources, workspace } = require('coc.nvim');
const schemas = require('./schemas');
const { debounce } = require('./utils');
const aliasParser = require('./alias_parser');
const Mapper = require('./mapper');
const { nvim } = workspace;

const cache = {};
const buffers = {};

const loadDadbodAdapters = async () => {
  const postgresAdapter = await nvim.getVar('db_adapter_postgres');
  const sqliteAdapter = await nvim.getVar('db_adapter_sqlite3');
  if (!postgresAdapter) {
    await nvim.command('let g:db_adapter_postgres = "db#adapter#postgresql#"');
  }
  if (!sqliteAdapter) {
    await nvim.command('let g:db_adapter_sqlite3 = "db#adapter#sqlite#"');
  }
};

const cacheTableAliases = async (bufnr) => {
  const content = await nvim.call('getbufline', [bufnr, 1, '$']);
  try {
    const aliases = aliasParser(content.join(' ').trim(), cache[buffers[bufnr].db].tables);
    buffers[bufnr].aliases = aliases;
  } catch (err) {
    console.debug('Failed to parse sql: ', err);
  }
};

const saveToCache = async (bufnr, db, table = null, dbui = null) => {
  if (!db) {
    return;
  }

  let tables = [];
  buffers[bufnr] = buffers[bufnr] || {};
  buffers[bufnr].aliases = buffers[bufnr].aliases || {};

  if (dbui !== null) {
    buffers[bufnr].scheme = dbui.scheme;
    if (dbui.connected) {
      tables = dbui.tables;
    }
  } else {
    const parsed = await nvim.call('db#url#parse', db);
    buffers[bufnr].scheme = parsed.scheme;
  }

  buffers[bufnr].table = table;
  buffers[bufnr].db = db;

  if (cache[db]) {
    return;
  }

  cache[db] = { tables, columns: [] };

  try {
    await loadDadbodAdapters();
    if (!cache[db].tables.length) {
      const tables = await nvim.call('db#adapter#call', [db, 'tables', [db], []]);
      cache[db].tables = [...new Set(tables)];
    }

    if (schemas[buffers[bufnr].scheme]) {
      let baseQuery = await nvim.call('db#adapter#dispatch', [db, 'interactive']);
      const columns = await nvim.call('systemlist', [`${baseQuery} ${schemas[buffers[bufnr].scheme].column_query}`]);
      cache[db].columns = schemas[buffers[bufnr].scheme].columnParser(columns);
    }
  } catch (err) {
    console.debug('COC DB ERROR: ', err);
    await nvim.command(`echohl ErrorMsg | echom "${err.message}" | echohl None`);
  }
}

const fetchTablesAndColumns = async (bufnr) => {
  const dbuiDbKeyName = await nvim.call('getbufvar', [bufnr, 'dbui_db_key_name']);
  const dbuiDbTableName = await nvim.call('getbufvar', [bufnr, 'dbui_table_name']);

  if (dbuiDbKeyName) {
    const dbui = await nvim.call('db_ui#get_conn_info', [dbuiDbKeyName]);
    return saveToCache(bufnr, dbui.url, dbuiDbTableName, dbui);
  }

  let db = await nvim.call('getbufvar', [bufnr, 'db']);
  if (!db) {
    db = await nvim.getVar('db');
  }
  const table = await nvim.call('getbufvar', [bufnr, 'db_table']);

  return saveToCache(bufnr, db, table);
};

const cacheAliases = debounce(cacheTableAliases, 250);

exports.activate = context => {
  workspace.onDidOpenTextDocument(e => {
    const doc = workspace.getDocument(e.uri);
    if (doc.filetype === 'sql') {
      return fetchTablesAndColumns(doc.bufnr);
    }
  });

  const source = {
    name: 'db',
    doComplete: async function (opt) {
      const { input, triggerCharacter, bufnr } = opt;
      const isTriggerCharacter = this.getConfig('triggerCharacters').includes(triggerCharacter);
      if (!input.length && !isTriggerCharacter) return null;

      cacheAliases(bufnr);
      const mapper = new Mapper(opt, this.menu, buffers[bufnr], isTriggerCharacter);

      Object.keys(cache).map((key) => {
        if (!mapper.tableScope) {
          cache[key].tables.map(table => mapper.add(table, 'table'));
          Object.keys(buffers[bufnr].aliases).map(table => mapper.add(buffers[bufnr].aliases[table], `alias to ${table}`))
        }
        cache[key].columns.map(column => mapper.add(column, 'column'));
      });

      return { items: mapper.items };
    },
  };

  context.subscriptions.push(sources.createSource(source));
};
