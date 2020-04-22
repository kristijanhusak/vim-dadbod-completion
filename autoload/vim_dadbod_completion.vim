let s:cache = {}
let s:buffers = {}

let s:trigger_rgx = '\(\.\|"\)$'

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

  if empty(a:base) && !is_trigger_char
    return []
  endif

  let completions = []

  let bufnr = bufnr('%')
  let buf = s:buffers[bufnr]
  let s:buffers[bufnr].aliases = vim_dadbod_completion#alias_parser#parse(bufnr, s:cache[buf.db].tables)

  let table_scope_match = matchlist(line, '"\?\(\w\+\)"\?\."\?\w*"\?$')
  let table_scope = get(table_scope_match, 1, '')

  let db_info = s:get_buffer_db_info(bufnr('%'))
  let cache_db = s:cache[db_info.url]

  if empty(table_scope)
    for table in cache_db.tables
      call s:add_match(completions, is_trigger_char, current_char, a:base, table, 'table')
    endfor

    for [tbl, alias] in items(s:buffers[bufnr].aliases)
      call s:add_match(completions, is_trigger_char, current_char a:base, alias, 'alias for table '.tbl)
    endfor
  endif

  for column in cache_db.columns
    if !s:matches_table_scope(bufnr, table_scope, column[0]) || !s:matches_table_scope(bufnr, db_info.table, column[0])
      continue
    endif

    call s:add_match(completions, is_trigger_char, current_char, a:base, column[1], 'column')
  endfor
  return completions
endfunction

function! s:add_match(completions, is_trigger_char, current_char, base, value, info) abort
  if a:is_trigger_char || a:value =~? '^"\?'.a:base
    call add(a:completions, {
          \ 'word': s:quote(a:value, a:current_char),
          \ 'menu': '[DB]',
          \ 'abbr': a:value,
          \ 'info': a:info
          \ })
  endif
endfunction

function s:matches_table_scope(bufnr, table_scope, table) abort
  if empty(a:table_scope)
    return 1
  endif

  let alias = get(s:buffers[a:bufnr].aliases, a:table, '')
  if a:table ==? a:table_scope || (!empty(alias) && alias ==? a:table_scope)
    return 1
  endif

  return 0
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
    let db = g:db
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

  let s:cache[a:db] = { 'tables': tables, 'columns': [] }

  try
    if empty(s:cache[a:db].tables)
      let tables = db#adapter#call(a:db, 'tables', [a:db], [])
      let s:cache[a:db].tables = uniq(tables)
    endif

    let scheme = vim_dadbod_completion#schemas#get(s:buffers[a:bufnr].scheme)
    if !empty(scheme)
      let base_query = db#adapter#dispatch(a:db, 'interactive')
      let result = systemlist(printf('%s %s', base_query, scheme.column_query))
      let s:cache[a:db].columns = call(scheme.column_parser, [result])
    endif
  catch /.*/
    echoerr v:exception
  endtry
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
