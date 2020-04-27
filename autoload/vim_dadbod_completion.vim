let s:cache = {}
let s:buffers = {}

let s:trigger_rgx = '\(\.\|"\)$'
let s:mark = get(g:, 'vim_dadbod_completion_mark', '[DB]')

function! vim_dadbod_completion#omni(findstart, base)
  let line = getline('.')[0:col('.') - 2]
  let current_char = getline('.')[col('.') - 2]
  if a:findstart
    let trigger_char = match(line, s:trigger_rgx)
    if trigger_char > -1
      return trigger_char + 1
    endif
    return match(line, '\(\s\+\|\.\)\@<="\?\w\+"\?$')
  endif

  let is_trigger_char = current_char =~? s:trigger_rgx
  let bufnr = bufnr('%')

  if empty(a:base) && !is_trigger_char || !has_key(s:buffers, bufnr)
    return []
  endif

  let completions = []

  let buf = s:buffers[bufnr]
  let s:buffers[bufnr].aliases = vim_dadbod_completion#alias_parser#parse(bufnr, s:cache[buf.db].tables)

  let table_scope_match = matchlist(line, '"\?\(\w\+\)"\?\."\?\w*"\?$')
  let table_scope = get(table_scope_match, 1, '')

  let db_info = s:get_buffer_db_info(bufnr('%'))
  let cache_db = s:cache[db_info.url]

  let tables = []
  let aliases = []
  let columns = []
  let should_filter = !(empty(a:base) && is_trigger_char)

  if empty(table_scope)
    let tables = copy(cache_db.tables)
    if should_filter
      call filter(tables, 'v:val =~? ''^"\?''.a:base')
    endif
    call map(tables, {_, table -> {'word': s:quote(table, current_char), 'abbr': table, 'menu': s:mark, 'info': 'table'}})

    let aliases = items(s:buffers[bufnr].aliases)
    if should_filter
      call filter(aliases, 'v:val[1] =~? ''^"\?''.a:base')
    endif
    call map(aliases, {table, alias -> {'word': s:quote(alias[1], current_char), 'abbr': alias[1], 'menu': s:mark, 'info': 'alias for table '.alias[0]}})
  endif

  let table_scope = s:get_table_scope(bufnr, cache_db, table_scope)
  let buffer_table_scope = s:get_table_scope(bufnr, cache_db, db_info.table)

  if !empty(table_scope)
    let columns = copy(cache_db.columns_by_table[table_scope])
  elseif !empty(buffer_table_scope)
    let columns = copy(cache_db.columns_by_table[buffer_table_scope])
  else
    let columns = copy(cache_db.columns)
  endif

  if should_filter
    call filter(columns, 'v:val[1] =~? ''^"\?''.a:base')
  endif

  call map(columns, {_, column -> {'word': s:quote(column[1], current_char), 'abbr': column[1], 'menu': s:mark, 'info': column[0].' table column' }})

  return tables + aliases + columns
endfunction

function! s:get_table_scope(bufnr, cache_db, table_scope) abort
  if empty(a:table_scope)
    return ''
  endif

  if has_key(a:cache_db.columns_by_table, a:table_scope)
    return a:table_scope
  endif

  let alias = filter(copy(s:buffers[a:bufnr].aliases), 'v:val ==? a:table_scope')

  if empty(alias)
    return ''
  endif

  return keys(alias)[0]
endfunction

function! vim_dadbod_completion#fetch(bufnr) abort
  if !exists('g:db_adapter_postgres')
    let g:db_adapter_postgres = 'db#adapter#postgresql#'
  endif

  if !exists('g:db_adapter_sqlite3')
    let g:db_adapter_sqlite3 = 'db#adapter#sqlite#'
  endif

  if getbufvar(a:bufnr, '&filetype') !=? 'sql'
    return
  endif
  let db_info = s:get_buffer_db_info(a:bufnr)

  return s:save_to_cache(a:bufnr, db_info.url, db_info.table, db_info.dbui)
endfunction

function! s:get_buffer_db_info(bufnr) abort
  let dbui_db_key_name = getbufvar(a:bufnr, 'dbui_db_key_name')
  let dbui_table_name = getbufvar(a:bufnr, 'dbui_table_name')

  if !empty(dbui_db_key_name)
    let dbui = db_ui#get_conn_info(dbui_db_key_name)
    return {
          \ 'url': dbui.url,
          \ 'table': dbui_table_name,
          \ 'dbui': dbui,
          \ }
  endif

  let db = getbufvar(a:bufnr, 'db')
  if empty(db)
    let db = get(g:, 'db', '')
  endif
  let db_table = getbufvar(a:bufnr, 'db_table')
  return {
        \ 'url': db,
        \ 'table': db_table,
        \ 'dbui': {},
        \ }
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
      let tables = a:dbui.tables
    endif
  else
    let parsed = db#url#parse(a:db)
    let s:buffers[a:bufnr].scheme = parsed.scheme
  endif

  let s:buffers[a:bufnr].table = a:table
  let s:buffers[a:bufnr].db = a:db

  if has_key(s:cache, a:db)
    return
  endif

  let s:cache[a:db] = { 'tables': tables, 'columns': [], 'columns_by_table': {} }

  try
    if empty(s:cache[a:db].tables)
      let tables = db#adapter#call(a:db, 'tables', [a:db], [])
      let s:cache[a:db].tables = uniq(tables)
    endif

    let scheme = vim_dadbod_completion#schemas#get(s:buffers[a:bufnr].scheme)
    if !empty(scheme)
      let base_query = db#adapter#dispatch(a:db, 'interactive')
      call vim_dadbod_completion#job#run(printf('%s %s', base_query, scheme.column_query), function('s:cache_columns', [a:db, scheme]))
    endif
  catch /.*/
    echoerr v:exception
  endtry
endfunction

function! s:cache_columns(db, scheme, result) abort
  let columns = call(a:scheme.column_parser, [a:result])
  let s:cache[a:db].columns = columns
  call map(copy(columns), function('s:map_columns_by_table', [a:db]))
endfunction

function! s:map_columns_by_table(db, index, column) abort
  if !has_key(s:cache[a:db].columns_by_table, a:column[0])
    let s:cache[a:db].columns_by_table[a:column[0]] = []
  endif
  call add(s:cache[a:db].columns_by_table[a:column[0]], a:column)
  return a:column
endfunction

function! s:quote(val, current_char) abort
  if !has_key(s:buffers, bufnr('%'))
    return a:val
  endif
  let scheme = vim_dadbod_completion#schemas#get(s:buffers[bufnr('%')].scheme)
  if empty(scheme) || !scheme.quote
    return a:val
  endif
  if a:val =~# '[A-Z]'
    let wrap = a:current_char =~? '"$' ? '' : '"'
    return wrap.a:val.wrap
  endif

  return a:val
endfunction
