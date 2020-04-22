let s:query = 'select table_name,column_name from information_schema.columns order by column_name asc'

function! s:parse_postgres(columns) abort
  let last = len(a:columns) - 1
  let list = a:columns[1:(last - 1)]
  return map(list, { _, table -> map(split(table, '|'), 'trim(v:val)') })
endfunction

function s:parse_mysql(columns) abort
  let list = a:columns[1:]
  return map(list, { _, table -> map(split(table, '\t'), 'trim(v:val)') })
endfunction

function s:parse_sqlserver(columns) abort
  let last = len(a:columns) - 1
  let list = a:columns[0:(last - 2)]
  return map(list, { _, table -> map(split(table, ' '), 'trim(v:val)') })
endfunction

let s:postgres = {
      \ 'column_query': printf("-A -c '%s'", s:query),
      \ 'quote': 1,
      \ 'column_parser': function('s:parse_postgres')
      \ }

let s:schemas = {
      \ 'postgres': s:postgres,
      \ 'postgresql': s:postgres,
      \ 'mysql': {
      \   'column_query': printf("-e '%s'", s:query),
      \   'quote': 0,
      \   'column_parser': function('s:parse_mysql')
      \ },
      \ 'sqlserver': {
      \   'column_query': printf("-h-1 -W -Q '%s'", s:query),
      \   'quote': 0,
      \   'column_parser': function('s:parse_sqlserver'),
      \ },
    \ }
function! vim_dadbod_completion#schemas#get(scheme)
  return get(s:schemas, a:scheme, {})
endfunction

