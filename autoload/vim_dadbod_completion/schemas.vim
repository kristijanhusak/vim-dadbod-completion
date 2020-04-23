let s:query = 'select table_name,column_name from information_schema.columns order by column_name asc'

function s:map_and_filter(delimiter, list) abort
  return filter(
        \ map(a:list, { _, table -> map(split(table, a:delimiter), 'trim(v:val)') }),
        \ 'len(v:val) ==? 2'
        \ )
endfunction

let s:postgres = {
      \ 'column_query': printf("-A -c '%s'", s:query),
      \ 'quote': 1,
      \ 'column_parser': function('s:map_and_filter', ['|'])
      \ }

let s:schemas = {
      \ 'postgres': s:postgres,
      \ 'postgresql': s:postgres,
      \ 'mysql': {
      \   'column_query': printf("-e '%s'", s:query),
      \   'quote': 0,
      \   'column_parser': function('s:map_and_filter', ['\t'])
      \ },
      \ 'sqlserver': {
      \   'column_query': printf("-h-1 -W -Q '%s'", s:query),
      \   'quote': 0,
      \   'column_parser': function('s:map_and_filter', [' ']),
      \ },
    \ }

function! vim_dadbod_completion#schemas#get(scheme)
  return get(s:schemas, a:scheme, {})
endfunction

