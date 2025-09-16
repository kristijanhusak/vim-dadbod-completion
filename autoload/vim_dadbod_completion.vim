let s:cache = {}
let s:buffers = {}
let s:filetypes = ['sql', 'mysql', 'plsql']

let s:quotes = vim_dadbod_completion#schemas#get_quotes_rgx()
let s:trigger_rgx = printf('\(%s\|\.\)$', s:quotes.open)
let s:findstart_rgx = printf('\(^\|\s\+\|\.\|(\|%s\)\@<=\w\+\(%s\)\?$', s:quotes.open, s:quotes.close)
let s:table_scope_rgx = printf('\(%s\)\?\(\w\+\)\(%s\)\?\.\(%s\)\?\w*\(%s\)\?$', s:quotes.open, s:quotes.close, s:quotes.open, s:quotes.close)
let s:filter_rgx = printf('^\(%s\)\?', s:quotes.open)
let s:mark = get(g:, 'vim_dadbod_completion_mark', '[DB]')
let s:default_limit = 200
let s:limits = get(g:, 'vim_dadbod_completion_source_limits', {})
let s:mapped_reserved_words = map(copy(vim_dadbod_completion#reserved_keywords#get()), {i,word ->
      \ {'word': word, 'abbr': word, 'menu': s:mark, 'info': 'SQL reserved word', 'kind': 'R' }
      \ })

function! vim_dadbod_completion#omni(findstart, base)
  let line = getline('.')[0:col('.') - 2]
  let current_char = getline('.')[col('.') - 2]
  if a:findstart
    let trigger_char = match(line, s:trigger_rgx)
    if trigger_char > -1
      return trigger_char + 1
    endif
    return match(line, s:findstart_rgx)
  endif

  let is_trigger_char = current_char =~? s:trigger_rgx
  let bufnr = bufnr('%')

  if empty(a:base) && !is_trigger_char
    return []
  endif

  if !has_key(s:buffers, bufnr)
    call vim_dadbod_completion#fetch(bufnr(''))
  endif

  " Nothing found, returning empty
  if !has_key(s:buffers, bufnr)
    return []
  endif

  let buf = s:buffers[bufnr]
  let s:buffers[bufnr].aliases = vim_dadbod_completion#alias_parser#parse(bufnr, s:cache[buf.db].tables_list)

  let table_scope_match = get(matchlist(line, s:table_scope_rgx), 2, '')
  let table_scope = s:get_scope(buf, table_scope_match, 'table')
  let buffer_table_scope = s:get_scope(buf, buf.table, 'table')
  let schema_scope = s:get_scope(buf, table_scope_match, 'schema')

  let cache_db = s:cache[buf.db]

  let tables = []
  let schemas = []
  let aliases = []
  let columns = []
  let reserved_words = []
  let bind_params = []
  let functions = []
  let should_filter = !(empty(a:base) && is_trigger_char)
  let bind_params_match = match(line, '[[:blank:]]*:\w*$') > -1

  if bind_params_match && exists('b:dbui_bind_params')
    for [param_name, param_val] in items(b:dbui_bind_params)
      call add(bind_params, {
            \ 'word': param_name[1:],
            \ 'abbr': param_name,
            \ 'menu': s:mark,
            \ 'info': param_val
            \ })
    endfor
  endif

  if empty(table_scope) && empty(schema_scope)
    let tables = copy(cache_db.tables)
    if should_filter
      call filter(tables, 'v:val.abbr =~? s:filter_rgx.a:base')
    endif
    let tables = tables[0:s:limit('tables')]

    let schemas = keys(cache_db.schemas)
    if should_filter
      call filter(schemas, 'v:val =~? s:filter_rgx.a:base')
    endif
    let schemas = schemas[0:s:limit('schemas')]
    call map(schemas, function('s:map_item', ['string', 'schema', 'S']))

    for [tbl, alias] in items(s:buffers[bufnr].aliases)
      for a in alias
        call add(aliases, [tbl, a])
      endfor
    endfor

    if should_filter
      call filter(aliases, 'v:val[1] =~? s:filter_rgx.a:base')
    endif
    call map(aliases, function('s:map_item', ['list', 'alias for table %s', 'A']))

    if !is_trigger_char
      let reserved_words = copy(s:mapped_reserved_words)
      if !empty(a:base)
        call filter(reserved_words, 'v:val.abbr =~? ''^''.a:base')
      endif
      let reserved_words = reserved_words[0:s:limit('reserved_words')]
    endif

    let functions = copy(cache_db.functions)
    if !empty(a:base) && !is_trigger_char
      call filter(functions, 'v:val.abbr =~? ''^''.a:base')
    endif

    let functions = functions[0:s:limit('functions')]
  endif

  if !empty(schema_scope)
    let tables = copy(cache_db.schemas[schema_scope])
    if should_filter
      call filter(tables, 'v:val.abbr =~? s:filter_rgx.a:base')
    endif
    let tables = tables[0:s:limit('tables')]
  endif

  if !empty(table_scope)
    let columns = s:get_table_scope_columns(buf.db, table_scope)
  elseif !empty(buffer_table_scope)
    let columns = s:get_table_scope_columns(buf.db, buffer_table_scope)
  elseif !cache_db.fetch_columns_by_table && empty(schema_scope)
    let columns = copy(cache_db.columns)
  endif

  if should_filter
    call filter(columns, 'v:val.abbr =~? s:filter_rgx.a:base')
  endif

  let columns = columns[0:s:limit('columns')]

  return s:quote_results(bind_params + reserved_words + schemas + tables + aliases + columns + functions)
endfunction

function! s:map_item(type, info_val, kind, index, item) abort
  let word = a:type ==? 'string' ? a:item : a:item[1]
  let info = a:type ==? 'string' ? a:info_val : printf(a:info_val, a:item[0])
  return {
        \ 'word': word,
        \ 'abbr': word,
        \ 'menu': s:mark,
        \ 'kind': a:kind,
        \ 'info': info,
        \ }
endfunction

function vim_dadbod_completion#clear_cache() abort
  let s:cache = {}
  call vim_dadbod_completion#utils#msg('Cache cleared')
  if index(s:filetypes, &filetype) > -1
    call vim_dadbod_completion#utils#msg('Reloading completion for current buffer...')
    call vim_dadbod_completion#fetch(bufnr(''))
    call vim_dadbod_completion#utils#msg('Reloading completion for current buffer...Done.')
  endif
endfunction

function! vim_dadbod_completion#fetch(bufnr) abort
  if !has('nvim') && !exists('*job_start')
    let s:buffers[a:bufnr] = {}
    return
  endif
  if !exists('g:db_adapter_postgres')
    let g:db_adapter_postgres = 'db#adapter#postgresql#'
  endif

  if !exists('g:db_adapter_sqlite3')
    let g:db_adapter_sqlite3 = 'db#adapter#sqlite#'
  endif

  if index(s:filetypes, getbufvar(a:bufnr, '&filetype')) < 0 && empty(getbufvar(a:bufnr, 'dbui_db_key_name'))
    return
  endif
  let db_info = s:get_buffer_db_info(a:bufnr)

  return s:save_to_cache(a:bufnr, db_info.url, db_info.table, db_info.dbui)
endfunction

function! s:save_to_cache(bufnr, db, table, dbui) abort
  if empty(a:db)
    return
  endif

  let tables = []
  if !has_key(s:buffers, a:bufnr)
    let s:buffers[a:bufnr] = {}
  endif

  if !has_key(s:buffers[a:bufnr], 'aliases')
    let s:buffers[a:bufnr].aliases = {}
  endif

  if !empty(a:dbui)
    let s:buffers[a:bufnr].scheme = a:dbui.scheme
    if a:dbui.connected
      let tables = copy(a:dbui.tables)
    endif
  else
    let parsed = db#url#parse(a:db)
    let s:buffers[a:bufnr].scheme = parsed.scheme
  endif

  let s:buffers[a:bufnr].table = a:table
  let s:buffers[a:bufnr].db = a:db
  let s:buffers[a:bufnr].dbui = a:dbui

  if has_key(s:cache, a:db)
    return
  endif

  let s:cache[a:db] = {
        \ 'tables': tables,
        \ 'tables_list': copy(tables),
        \ 'schemas': {},
        \ 'columns': [],
        \ 'functions': [],
        \ 'columns_by_table': {},
        \ 'fetch_columns_by_table': 1,
        \ 'scheme': {}
        \ }

  if empty(s:cache[a:db].tables)
    let tables = db#adapter#call(a:db, 'tables', [a:db], [])
    let s:cache[a:db].tables = uniq(tables)
    let s:cache[a:db].tables_list = copy(s:cache[a:db].tables)
    call map(s:cache[a:db].tables, function('s:map_item', ['string', 'table', 'T']))
  elseif type(s:cache[a:db].tables[0]) ==? type('')
    call map(s:cache[a:db].tables, function('s:map_item', ['string', 'table', 'T']))
  endif

  let scheme = vim_dadbod_completion#schemas#get(s:buffers[a:bufnr].scheme)
  let s:cache[a:db].scheme = scheme
  if !empty(scheme)
    let ccq = s:generate_query(a:db, 'count_column_query')
    call vim_dadbod_completion#job#run(ccq[0], function('s:count_columns_and_cache', [a:db]), ccq[1])
    if has_key(scheme, 'functions_query')
      let fnq = s:generate_query(a:db, 'functions_query')
      call vim_dadbod_completion#job#run(fnq[0], function('s:parse_functions', [a:db]), fnq[1])
    endif
    if has_key(scheme, 'schemas_query')
      let scmq = s:generate_query(a:db, 'schemas_query')
      call vim_dadbod_completion#job#run(scmq[0], function('s:parse_schemas', [a:db]), scmq[1])
    endif
  endif
endfunction

function! s:parse_functions(db, functions) abort
  let s:cache[a:db].functions = s:cache[a:db].scheme.functions_parser(a:functions)
  call map(s:cache[a:db].functions, {i,fn -> {'word': fn, 'abbr': fn, 'menu': s:mark, 'info': 'Function', 'kind': 'F' }})
endfunction

function! s:parse_schemas(db, schemas) abort
  let data = s:cache[a:db].scheme.schemas_parser(a:schemas)
  for schema in data
    if !has_key(s:cache[a:db].schemas, schema[0])
      let s:cache[a:db].schemas[schema[0]] = []
    endif
    call add(s:cache[a:db].schemas[schema[0]], schema[1])
  endfor
  for k in keys(s:cache[a:db].schemas)
    call map(s:cache[a:db].schemas[k], function('s:map_item', ['string', 'table', 'T']))
  endfor
endfunction

function! s:generate_query(db, query_key, ...) abort
  let scheme = s:cache[a:db].scheme
  let base_query = db#adapter#dispatch(a:db, 'interactive') + get(scheme, 'args', [])
  let Query = scheme[a:query_key]
  if a:0 > 0
    let Query = Query(a:1)
  endif
  if get(scheme, 'requires_stdin')
    return [base_query, Query]
  endif
  return [base_query + [Query], '']
endfunction

function! s:count_columns_and_cache(db, count) abort
  let column_count = s:cache[a:db].scheme.count_parser(a:count)
  if column_count <= 10000
    let [query, stdin] = s:generate_query(a:db, 'column_query')
    call vim_dadbod_completion#job#run(query, function('s:cache_all_columns', [a:db]), stdin)
  endif
endfunction

function! s:cache_all_columns(db, result) abort
  let columns = call(s:cache[a:db].scheme.column_parser, [a:result])
  let s:cache[a:db].columns = map(copy(columns), function('s:map_item', ['list', '%s table column', 'C']))
  call map(copy(columns), function('s:map_columns_by_table', [a:db]))
  let s:cache[a:db].fetch_columns_by_table = 0
endfunction

function! s:map_columns_by_table(db, index, column) abort
  if !has_key(s:cache[a:db].columns_by_table, a:column[0])
    let s:cache[a:db].columns_by_table[a:column[0]] = []
  endif
  call add(s:cache[a:db].columns_by_table[a:column[0]], s:map_item('list', '%s table column', 'C', 0, a:column))
  return a:column
endfunction

function! s:get_table_scope_columns(db, table_scope) abort
  if has_key(s:cache[a:db].columns_by_table, a:table_scope)
    return copy(s:cache[a:db].columns_by_table[a:table_scope])
  endif

  if empty(s:cache[a:db].scheme)
    return []
  endif

  let g:vim_dadbod_completion_refresh_deoplete = 1

  call vim_dadbod_completion#utils#msg(printf('Fetching columns for table %s...', a:table_scope))
  let [query, stdin] = s:generate_query(a:db, 'table_column_query', a:table_scope)
  call vim_dadbod_completion#job#run(query, function('s:cache_table_columns', [a:db, a:table_scope]), stdin)
  return []
endfunction

function! s:cache_table_columns(db, table_scope, result)
  let s:cache[a:db].columns_by_table[a:table_scope] = []
  let columns = call(s:cache[a:db].scheme.column_parser, [a:result])
  call map(columns, function('s:map_columns_by_table', [a:db]))
  if exists('*coc#refresh')
    call coc#start()
  elseif exists('g:loaded_deoplete')
    let g:vim_dadbod_completion_refresh_deoplete = 0
  elseif exists('g:loaded_compe')
    call compe#complete()
  elseif exists('g:loaded_completion') && exists('*completion#completion_wrapper')
    call completion#completion_wrapper()
  elseif &omnifunc ==? 'vim_dadbod_completion#omni'
    call feedkeys("\<C-x>\<C-o>")
  endif
  call vim_dadbod_completion#utils#msg(printf('Fetching columns for table %s...Done.', a:table_scope))
endfunction

function! s:get_scope(buffer, table_scope, type) abort
  let cache_db = s:cache[a:buffer.db]
  if empty(a:table_scope)
    return ''
  endif

  if a:type ==? 'schema'
    if has_key(cache_db.schemas, a:table_scope)
      return a:table_scope
    endif
    return ''
  endif

  if has_key(cache_db.columns_by_table, a:table_scope)
    return a:table_scope
  endif

  let is_valid = index(cache_db.tables_list, a:table_scope) > -1

  if is_valid
    return a:table_scope
  endif

  let alias = filter(copy(a:buffer.aliases), 'index(v:val, a:table_scope) > -1')

  if empty(alias)
    return ''
  endif

  let alias_table = keys(alias)[0]

  if index(cache_db.tables_list, alias_table) > -1
    return alias_table
  endif

  return ''
endfunction

function! s:get_buffer_db_info(bufnr) abort
  let dbui_db_key_name = getbufvar(a:bufnr, 'dbui_db_key_name')
  let dbui_table_name = getbufvar(a:bufnr, 'dbui_table_name')

  if !empty(dbui_db_key_name)
    let dbui = db_ui#get_conn_info(dbui_db_key_name)
    let conn = dbui.conn
    if empty(conn)
      let conn = db#connect(dbui.url)
    endif
    return {
          \ 'url': conn,
          \ 'table': dbui_table_name,
          \ 'dbui': dbui,
          \ }
  endif

  let db = $DATABASE_URL
  for dict in [w:, t:, b:, g:]
    if has_key(dict, 'db') && !empty(dict.db)
      let db = dict.db
      break
    endif
  endfor
  if !empty(db)
    call vim_dadbod_completion#utils#msg('Connecting to db...')
    let db = db#connect(db#resolve(db))
    call vim_dadbod_completion#utils#msg('Connecting to db...Done.')
  endif
  let db_table = getbufvar(a:bufnr, 'db_table')
  return {
        \ 'url': db,
        \ 'table': db_table,
        \ 'dbui': {},
        \ }
endfunction

function! s:quote(scheme, left_wrap, right_wrap, index, item) abort
  if a:item.kind !=? 'F' && a:item.kind !=? 'R' && a:scheme.should_quote(a:item.abbr)
    let a:item.word = a:left_wrap.a:item.abbr.a:right_wrap
  endif
  return a:item
endfunction

function! s:quote_results(results) abort
  if !has_key(s:buffers, bufnr('%'))
    return a:results
  endif
  let scheme = vim_dadbod_completion#schemas#get(s:buffers[bufnr('%')].scheme)

  if empty(scheme)
    return a:results
  endif

  let line = getline('.')
  let [l_quote, r_quote] = scheme.quote
  let l_quote_esc = escape(l_quote, '[')
  let r_quote_esc = escape(r_quote, ']')
  let left_wrap = match(line, l_quote_esc.'\w*\%'.col('.').'c') > -1 ? '' : l_quote
  let right_wrap = matchstr(line, '\%>'.(col('.') - 1).'c['.r_quote_esc.' \.]') !=? r_quote ? r_quote : ''

  return map(a:results, function('s:quote', [scheme, left_wrap, right_wrap]))
endfunction

function! s:limit(type) abort
  return get(s:limits, a:type, s:default_limit)
endfunction

function! vim_dadbod_completion#refresh_deoplete() abort
  return get(g:, 'vim_dadbod_completion_refresh_deoplete', 0)
endfunction
